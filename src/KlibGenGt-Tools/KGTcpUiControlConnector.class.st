"Exchange live UI control envelopes over a loopback TCP NDJSON stream.

- Slots
  - `port` (`#Integer`, `endpoint`) - Requested listen port; zero allocates one.
  - `boundPort` (`#Integer`, `endpoint`) - Actual bound port.
  - `serverSocket` (`#(Socket?)`, `transport`) - Loopback listener.
  - `worker` (`#(Process?)`, `lifecycle`) - Connection accept loop.
  - `clientSockets` (`#(IdentitySet<Socket>)`, `transport`) - Accepted sockets.
  - `clientProcesses` (`#(IdentitySet<Process>)`, `lifecycle`) - Connection workers.
  - `clientsMutex` (`#Mutex`, `lifecycle`) - Protects client collections.
  - `running` (`#Boolean`, `lifecycle`) - Listener state.
  - `maxRequestBytes` (`#Integer`, `limits`) - Maximum UTF-8 request line size.
- Public API
  - {{gtMethod:KGTcpUiControlConnector class>>#onPort:}}
    Create a dormant loopback connector.
  - {{gtMethod:KGTcpUiControlConnector>>#port:}}
    Configure the listen port.
  - {{gtMethod:KGTcpUiControlConnector>>#boundPort}}
    Answer the actual bound port.
  - {{gtMethod:KGTcpUiControlConnector>>#endpoint}}
    Describe the loopback NDJSON endpoint.
  - {{gtMethod:KGTcpUiControlConnector>>#start}}
    Bind loopback and accept connections.
  - {{gtMethod:KGTcpUiControlConnector>>#stop}}
    Stop and release all connections.
"
Class { #name : 'KGTcpUiControlConnector', #superclass : 'KGUiControlConnector', #instVars : [ 'port', 'boundPort', 'serverSocket', 'worker', 'clientSockets', 'clientProcesses', 'clientsMutex', 'running', 'maxRequestBytes' ], #category : 'KlibGenGt-Tools', #package : 'KlibGenGt-Tools' }

{ #category : 'instance creation' }
KGTcpUiControlConnector class >> onPort: aPort [ <arg: #aPort type: #Integer> <return: #KGTcpUiControlConnector> ^ self new port: aPort ]

{ #category : 'initialization' }
KGTcpUiControlConnector >> initialize [
	super initialize. port := 0. boundPort := 0. running := false. maxRequestBytes := 1024 * 1024.
	clientSockets := IdentitySet new. clientProcesses := IdentitySet new. clientsMutex := Mutex new
]

{ #category : 'accessing' }
KGTcpUiControlConnector >> port: aPort [
	<arg: #aPort type: #Integer> <return: #KGTcpUiControlConnector>
	(aPort between: 0 and: 65535) ifFalse: [ self error: 'TCP UI control port must be between 0 and 65535' ].
	running ifTrue: [ self error: 'cannot change the port of a running TCP UI control connector' ]. port := aPort. ^ self
]

{ #category : 'accessing' }
KGTcpUiControlConnector >> boundPort [ <return: #Integer> ^ boundPort ]

{ #category : 'accessing' }
KGTcpUiControlConnector >> endpoint [
	<return: #(Dictionary<String, Any>)>
	^ OrderedDictionary new at: 'connector' put: 'tcp'; at: 'host' put: '127.0.0.1'; at: 'port' put: boundPort; at: 'framing' put: 'ndjson'; at: 'maxRequestBytes' put: maxRequestBytes; yourself
]

{ #category : 'public - lifecycle' }
KGTcpUiControlConnector >> start [
	<return: #KGTcpUiControlConnector>
	running ifTrue: [ ^ self ]. serverSocket := Socket newTCP.
	[ serverSocket listenOn: port backlogSize: 16 interface: #[127 0 0 1]. boundPort := serverSocket localPort ] on: Exception do: [ :error | serverSocket closeAndDestroy. serverSocket := nil. error pass ].
	running := true. worker := [ self acceptLoop ] forkAt: Processor userBackgroundPriority. ^ self
]

{ #category : 'public - lifecycle' }
KGTcpUiControlConnector >> stop [
	<return: #KGTcpUiControlConnector>
	| sockets processes |
	running := false. serverSocket ifNotNil: [ serverSocket closeAndDestroy ]. serverSocket := nil.
	worker ifNotNil: [ worker terminate ]. worker := nil.
	clientsMutex critical: [ sockets := clientSockets asArray. processes := clientProcesses asArray. clientSockets removeAll. clientProcesses removeAll ].
	sockets do: [ :socket | [ socket closeAndDestroy ] on: Error do: [ ] ]. processes do: [ :process | process terminate ]. boundPort := 0. ^ self
]

{ #category : 'private - connections' }
KGTcpUiControlConnector >> acceptLoop [
	[ running ] whileTrue: [ | socket process |
		socket := [ serverSocket waitForAcceptFor: 0.2 ] on: Exception do: [ :error | running ifTrue: [ error pass ]. nil ].
		socket ifNotNil: [ clientsMutex critical: [ clientSockets add: socket ]. process := [ self handleClient: socket ] newProcess. process priority: Processor userBackgroundPriority. clientsMutex critical: [ clientProcesses add: process ]. process resume ] ]
]

{ #category : 'private - connections' }
KGTcpUiControlConnector >> handleClient: socket [
	| stream line response |
	stream := SocketStream on: socket. stream binary.
	([ [ running and: [ (line := self readLineFrom: stream) notNil ] ] whileTrue: [ line isEmpty ifFalse: [ response := service responseForSerializedRequest: line defaultRequestId: 'unknown'. self writeResponse: response on: stream ] ] ] on: Exception do: [ :error | response := service failureFor: error requestId: 'unknown' operation: 'unknown'. [ self writeResponse: response on: stream ] on: Error do: [ ] ]) ensure: [ [ stream close ] on: Error do: [ ]. clientsMutex critical: [ clientSockets remove: socket ifAbsent: [ ]. clientProcesses remove: Processor activeProcess ifAbsent: [ ] ] ]
]

{ #category : 'private - framing' }
KGTcpUiControlConnector >> readLineFrom: stream [
	| bytes byte contents |
	bytes := ByteArray new writeStream.
	[ byte := stream next. byte ifNil: [ ^ bytes position = 0 ifTrue: [ nil ] ifFalse: [ bytes contents utf8Decoded ] ].
		byte = Character lf asciiValue ifTrue: [ contents := bytes contents. (contents notEmpty and: [ contents last = Character cr asciiValue ]) ifTrue: [ contents := contents allButLast ]. ^ contents utf8Decoded ].
		bytes position >= maxRequestBytes ifTrue: [ self error: 'TCP UI control request exceeds 1048576 bytes' ]. bytes nextPut: byte ] repeat
]

{ #category : 'private - framing' }
KGTcpUiControlConnector >> writeResponse: response on: stream [
	| payload | payload := (STONJSON toString: response) utf8Encoded. stream nextPutAll: payload; nextPut: Character lf asciiValue; flush
]
