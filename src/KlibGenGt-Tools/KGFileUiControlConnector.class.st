"Exchange live UI control envelopes through a session-private atomic filesystem spool.

- Slots
  - `root` (`#FileReference`, `spool`) - Session-private `tmp/ui-control` directory.
  - `requests` (`#FileReference`, `spool`) - Atomic incoming request directory.
  - `responses` (`#FileReference`, `spool`) - Atomic response directory.
  - `worker` (`#(Process?)`, `lifecycle`) - Filesystem polling worker.
  - `running` (`#Boolean`, `lifecycle`) - Polling loop state.
- Public API
  - {{gtMethod:KGFileUiControlConnector>>#start}}
    Prepare the spool, publish readiness, and start polling requests.
  - {{gtMethod:KGFileUiControlConnector>>#stop}}
    Stop polling and remove stale request and readiness files.
"
Class { #name : 'KGFileUiControlConnector', #superclass : 'KGUiControlConnector', #instVars : [ 'root', 'requests', 'responses', 'worker', 'running' ], #category : 'KlibGenGt-Tools', #package : 'KlibGenGt-Tools' }

{ #category : 'initialization' }
KGFileUiControlConnector >> initialize [ super initialize. running := false ]

{ #category : 'private - spool' }
KGFileUiControlConnector >> deleteChildrenOf: aDirectory [
	aDirectory exists ifTrue: [ aDirectory children do: [ :each | each isDirectory ifTrue: [ each deleteAll ] ifFalse: [ each delete ] ] ]
]

{ #category : 'private - spool' }
KGFileUiControlConnector >> writeJson: anObject atomicallyTo: destination [
	| temporary stream output |
	temporary := destination parent / ('.', destination basename, '.tmp'). temporary ensureDelete.
	output := STONJSON toString: anObject. stream := temporary writeStream.
	[ stream nextPutAll: output; flush ] ensure: [ stream close ].
	destination ensureDelete. temporary renameTo: destination basename
]

{ #category : 'public - lifecycle' }
KGFileUiControlConnector >> start [
	<return: #KGFileUiControlConnector>
	running ifTrue: [ ^ self ].
	root := (Smalltalk os environment at: 'TMPDIR') asFileReference / 'ui-control'.
	requests := root / 'requests'. responses := root / 'responses'.
	requests ensureCreateDirectory. responses ensureCreateDirectory.
	self deleteChildrenOf: requests; deleteChildrenOf: responses.
	self writeJson: (OrderedDictionary new at: 'schemaVersion' put: 1; at: 'sessionId' put: service sessionId; at: 'ready' put: true; yourself) atomicallyTo: root / 'ready.json'.
	running := true. worker := [ self workerLoop ] forkAt: Processor userBackgroundPriority. ^ self
]

{ #category : 'public - lifecycle' }
KGFileUiControlConnector >> stop [
	<return: #KGFileUiControlConnector>
	running := false. worker ifNotNil: [ worker terminate ]. worker := nil.
	requests ifNotNil: [ self deleteChildrenOf: requests ]. root ifNotNil: [ (root / 'ready.json') ensureDelete ]. ^ self
]

{ #category : 'private - spool' }
KGFileUiControlConnector >> workerLoop [
	[ running ] whileTrue: [ | files | files := requests children select: [ :each | each extension = 'json' ]. files sorted do: [ :requestFile | self processFile: requestFile ]. (Delay forMilliseconds: 25) wait ]
]

{ #category : 'private - spool' }
KGFileUiControlConnector >> processFile: requestFile [
	| requestId operation response |
	requestId := requestFile basenameWithoutExtension. operation := 'unknown'.
	response := service responseForSerializedRequest: requestFile contents defaultRequestId: requestId.
	operation := response at: 'operation' ifAbsent: [ operation ]. requestId := response at: 'requestId' ifAbsent: [ requestId ].
	[ [ self writeJson: response atomicallyTo: responses / (requestId, '.json') ] on: Exception do: [ :error | self writeJson: (service failureFor: error requestId: requestId operation: operation) atomicallyTo: responses / (requestId, '.json') ] ] ensure: [ requestFile ensureDelete ]
]
