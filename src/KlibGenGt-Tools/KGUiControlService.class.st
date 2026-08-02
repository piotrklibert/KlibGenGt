"Validate and execute connector-independent live UI control requests.

- Slots
  - `connector` (`#KGUiControlConnector`, `transport`) - Supplies requests and returns responses.
  - `sessionId` (`#String`, `identity`) - Managed GUI session identifier accepted by this service.
  - `scene` (`#KGUiSceneGraph`, `inspection`) - Stable handle registry and scene inspector.
  - `requestMutex` (`#Mutex`, `requests`) - Serializes dispatch across connector clients.
  - `running` (`#Boolean`, `lifecycle`) - Service lifecycle state.
- Public API
  - {{gtMethod:KGUiControlService class>>#install}}
    Start exactly one service for the current managed GUI session.
  - {{gtMethod:KGUiControlService class>>#uninstall}}
    Stop the service and clear request/readiness state idempotently.
  - {{gtMethod:KGUiControlService class>>#current}}
    Answer the installed service, if any.
  - {{gtMethod:KGUiControlService>>#start}}
    Start the configured connector.
  - {{gtMethod:KGUiControlService>>#startWithConnector:}}
    Start with an explicitly supplied connector.
  - {{gtMethod:KGUiControlService>>#connector}}
    Answer the configured connector.
  - {{gtMethod:KGUiControlService>>#sessionId}}
    Answer the managed session identity.
  - {{gtMethod:KGUiControlService>>#stop}}
    Stop the worker and remove stale request/readiness files.
  - {{gtMethod:KGUiControlService>>#handle:}}
    Validate and execute one schema-version-one request.
  - {{gtMethod:KGUiControlService>>#handleSerialized:}}
    Serialize one decoded request across connector clients.
  - {{gtMethod:KGUiControlService>>#responseForSerializedRequest:defaultRequestId:}}
    Decode JSON and return success or structured failure.
"
Class {
	#name : 'KGUiControlService',
	#superclass : 'Object',
	#instVars : [ 'connector', 'sessionId', 'scene', 'requestMutex', 'running' ],
	#classVars : [ 'Current' ],
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'public - lifecycle' }
KGUiControlService class >> current [
	<return: #(KGUiControlService?)>
	^ Current
]

{ #category : 'public - lifecycle' }
KGUiControlService class >> install [
	<return: #KGUiControlService>
	Current ifNotNil: [ ^ Current ].
	Current := self new startWithConnector: KGFileUiControlConnector new.
	^ Current
]

{ #category : 'public - lifecycle' }
KGUiControlService class >> uninstall [
	<return: #KGUiControlService>
	Current ifNotNil: [ Current stop ].
	Current := nil.
	^ self
]

{ #category : 'initialization' }
KGUiControlService >> initialize [
	super initialize.
	running := false.
	connector := KGFileUiControlConnector new.
	requestMutex := Mutex new.
	scene := KGUiSceneGraph new
]

{ #category : 'accessing' }
KGUiControlService >> connector [ <return: #(KGUiControlConnector?)> ^ connector ]

{ #category : 'accessing' }
KGUiControlService >> sessionId [ <return: #String> ^ sessionId ]

{ #category : 'public - lifecycle' }
KGUiControlService >> start [
	<return: #KGUiControlService>
	running ifTrue: [ ^ self ].
	connector ifNil: [ connector := KGFileUiControlConnector new ].
	sessionId := KGSession current id.
	running := true.
	[ connector service: self; start ] on: Exception do: [ :error | running := false. error pass ].
	^ self
]

{ #category : 'public - lifecycle' }
KGUiControlService >> startWithConnector: aConnector [
	<arg: #aConnector type: #KGUiControlConnector> <return: #KGUiControlService>
	running ifTrue: [ self error: 'cannot replace a running UI control connector' ]. connector := aConnector. ^ self start
]

{ #category : 'public - lifecycle' }
KGUiControlService >> stop [
	<return: #KGUiControlService>
	running := false.
	connector ifNotNil: [ connector stop ].
	^ self
]

{ #category : 'public - requests' }
KGUiControlService >> responseForSerializedRequest: serializedRequest defaultRequestId: defaultRequestId [
	<arg: #serializedRequest type: #String> <arg: #defaultRequestId type: #String> <return: #(Dictionary<String, Any>)>
	| request requestId operation |
	requestId := defaultRequestId. operation := 'unknown'.
	^ [ request := STONJSON fromString: serializedRequest. requestId := request at: 'requestId' ifAbsent: [ requestId ]. operation := request at: 'operation' ifAbsent: [ operation ]. self handleSerialized: request ] on: Exception do: [ :error | self failureFor: error requestId: requestId operation: operation ]
]

{ #category : 'private - responses' }
KGUiControlService >> failureFor: anError requestId: requestId operation: operation [
	| stack kind |
	stack := anError signalerContext
		ifNil: [ #() ]
		ifNotNil: [ :context | context shortDebugStack lines ].
	kind := ((anError class name includesSubstring: 'Syntax') or: [ anError class name includesSubstring: 'Notice' ])
		ifTrue: [ 'compile' ] ifFalse: [ 'runtime' ].
	^ OrderedDictionary new
		at: 'schemaVersion' put: 1;
		at: 'requestId' put: requestId;
		at: 'sessionId' put: sessionId;
		at: 'operation' put: operation;
		at: 'ok' put: false;
		at: 'error' put: (OrderedDictionary new
			at: 'kind' put: kind;
			at: 'class' put: anError class name asString;
			at: 'message' put: anError messageText;
			at: 'stack' put: stack;
			yourself);
		yourself
]

{ #category : 'private - responses' }
KGUiControlService >> successFor: request data: data [
	^ OrderedDictionary new
		at: 'schemaVersion' put: 1;
		at: 'requestId' put: (request at: 'requestId');
		at: 'sessionId' put: sessionId;
		at: 'operation' put: (request at: 'operation');
		at: 'ok' put: true;
		at: 'data' put: data;
		yourself
]

{ #category : 'public - requests' }
KGUiControlService >> handle: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| operation data |
	(aRequest at: 'schemaVersion' ifAbsent: [ 0 ]) = 1 ifFalse: [ self error: 'unsupported UI control schema version' ].
	(aRequest at: 'sessionId' ifAbsent: [ '' ]) = sessionId ifFalse: [ self error: 'UI control session mismatch' ].
	(aRequest at: 'deadlineUnixMs' ifAbsent: [ 0 ]) < (DateAndTime now asUnixTime * 1000)
		ifTrue: [ self error: 'expired UI control request' ].
	operation := aRequest at: 'operation' ifAbsent: [ self error: 'request is missing operation' ].
	data := self dispatch: operation request: aRequest.
	^ self successFor: aRequest data: data
]

{ #category : 'public - requests' }
KGUiControlService >> handleSerialized: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)> <return: #(Dictionary<String, Any>)>
	^ requestMutex critical: [ self handle: aRequest ]
]

{ #category : 'private - requests' }
KGUiControlService >> dispatch: operation request: aRequest [
	operation = 'ui.status' ifTrue: [ ^ OrderedDictionary new at: 'ready' put: true; at: 'sessionId' put: sessionId; yourself ].
	operation = 'ui.spaces' ifTrue: [ ^ scene spacesData ].
	operation = 'ui.tree' ifTrue: [ ^ scene tree: aRequest ].
	operation = 'ui.query' ifTrue: [ ^ scene query: aRequest ].
	operation = 'ui.get' ifTrue: [ ^ self get: aRequest ].
	operation = 'ui.act' ifTrue: [ ^ self act: aRequest ].
	operation = 'ui.wait' ifTrue: [ ^ self wait: aRequest ].
	operation = 'ui.batch' ifTrue: [ ^ self batch: aRequest ].
	operation = 'ui.eval' ifTrue: [ ^ self evaluate: aRequest ].
	self error: 'unsupported UI control operation: ' , operation
]

{ #category : 'private - requests' }
KGUiControlService >> get: aRequest [
	| result |
	result := scene query: aRequest.
	(result at: 'count') = 1 ifFalse: [ self error: 'ui get requires exactly one match' ].
	^ (result at: 'matches') first
]

{ #category : 'private - requests' }
KGUiControlService >> act: aRequest [
	| target action scripter remaining |
	target := scene resolveOne: aRequest.
	action := aRequest at: 'action'.
	scripter := KGExistingSpaceScripter new attachToSpace: target space.
	remaining := ((aRequest at: 'deadlineUnixMs') - (DateAndTime now asUnixTime * 1000)) max: 1.
	scripter maxPulseElapsedTime: remaining milliSeconds.
	[ self onUiFor: target request: aRequest do: [ scripter act: action on: target request: aRequest ] ]
		ensure: [ scripter detach ].
	^ OrderedDictionary new
		at: 'action' put: action;
		at: 'target' put: (scene query: (Dictionary new at: 'node' put: (aRequest at: 'node' ifAbsent: [ scene perform: #handleFor: with: target ]); yourself));
		yourself
]

{ #category : 'private - requests' }
KGUiControlService >> onUiFor: target request: aRequest do: aBlock [
	| semaphore result error remaining |
	semaphore := Semaphore new.
	UIManager default defer: [
		[ [ result := aBlock value ] on: Exception do: [ :exception | error := exception ] ]
			ensure: [ semaphore signal ] ].
	remaining := ((aRequest at: 'deadlineUnixMs') - (DateAndTime now asUnixTime * 1000)) max: 1.
	(semaphore waitTimeoutMilliseconds: remaining) ifTrue: [ self error: 'UI action timed out waiting for the space process' ].
	error ifNotNil: [ error pass ].
	^ result
]

{ #category : 'private - waiting' }
KGUiControlService >> waitSatisfied: state request: aRequest result: result [
	| matches value |
	matches := result at: 'matches'.
	state = 'absent' ifTrue: [ ^ matches isEmpty ].
	matches isEmpty ifTrue: [ ^ false ].
	state = 'exists' ifTrue: [ ^ true ].
	state = 'visible' ifTrue: [ ^ matches anySatisfy: [ :each | each at: 'effectiveVisible' ] ].
	state = 'hidden' ifTrue: [ ^ matches allSatisfy: [ :each | (each at: 'effectiveVisible') not ] ].
	state = 'focused' ifTrue: [ ^ matches anySatisfy: [ :each | each at: 'focused' ] ].
	state = 'enabled' ifTrue: [ ^ matches anySatisfy: [ :each | each at: 'enabled' ] ].
	value := aRequest at: 'value' ifAbsent: [ '' ].
	state = 'text-equals' ifTrue: [ ^ matches anySatisfy: [ :each | (each at: 'text') = value ] ].
	state = 'text-contains' ifTrue: [ ^ matches anySatisfy: [ :each | (each at: 'text') includesSubstring: value ] ].
	self error: 'unsupported UI wait state: ' , state
]

{ #category : 'private - waiting' }
KGUiControlService >> wait: aRequest [
	| state result deadline |
	state := aRequest at: 'state'.
	deadline := aRequest at: 'deadlineUnixMs'.
	[ result := scene query: aRequest.
	(self waitSatisfied: state request: aRequest result: result) ifTrue: [
		^ OrderedDictionary new at: 'state' put: state; at: 'result' put: result; yourself ].
	DateAndTime now asUnixTime * 1000 < deadline ] whileTrue: [ (Delay forMilliseconds: 25) wait ].
	self error: 'UI wait timed out for state ' , state
]

{ #category : 'private - batches' }
KGUiControlService >> batch: aRequest [
	| completed index failure failingStep failureContext |
	completed := OrderedCollection new.
	index := 0.
	failure := nil.
	failureContext := nil.
	(aRequest at: 'steps') do: [ :step |
		failure ifNil: [
			index := index + 1.
			(step at: 'operation') = 'ui.eval' ifTrue: [ self error: 'live eval is not allowed in batches' ].
			[ completed add: (self dispatch: (step at: 'operation') request: (aRequest copy addAll: step; yourself)) ]
				on: Exception
				do: [ :error |
					failingStep := step.
					failure := self failureFor: error requestId: (aRequest at: 'requestId') operation: (step at: 'operation').
					failureContext := [ scene query: (step copy at: 'limit' put: 25; yourself) ]
						on: Error do: [ nil ] ] ] ].
	^ OrderedDictionary new
		at: 'completed' put: completed asArray;
		at: 'completedCount' put: completed size;
		at: 'failedStep' put: (failure ifNil: [ nil ] ifNotNil: [ index ]);
		at: 'failure' put: failure;
		at: 'failureContext' put: failureContext;
		at: 'step' put: failingStep;
		yourself
]

{ #category : 'private - evaluation' }
KGUiControlService >> evaluate: aRequest [
	| process semaphore result error remaining |
	semaphore := Semaphore new.
	process := [
		[ result := Smalltalk compiler evaluate: (aRequest at: 'expression') ]
			on: Exception do: [ :exception | error := exception ].
		semaphore signal ] forkAt: Processor userBackgroundPriority.
	remaining := ((aRequest at: 'deadlineUnixMs') - (DateAndTime now asUnixTime * 1000)) max: 1.
	(semaphore waitTimeoutMilliseconds: remaining) ifTrue: [
		process terminate.
		self error: 'live evaluation timed out' ].
	error ifNotNil: [ error pass ].
	^ OrderedDictionary new at: 'result' put: result printString; yourself
]
