"Serialize filesystem requests into live scene inspection and Scripter actions.

- Slots
  - `root` (`#FileReference`, `spool`) - Run-private `tmp/ui-control` directory.
  - `requests` (`#FileReference`, `spool`) - Atomic incoming request directory.
  - `responses` (`#FileReference`, `spool`) - Atomic response directory.
  - `runId` (`#String`, `identity`) - Managed GUI run identifier accepted by this service.
  - `scene` (`#KGUiSceneGraph`, `inspection`) - Stable handle registry and scene inspector.
  - `worker` (`#(Process?)`, `lifecycle`) - Single serialized request worker.
  - `running` (`#Boolean`, `lifecycle`) - Worker loop state.
- Public API
  - {{gtMethod:KGUiControlService class>>#install}}
    Start exactly one service for the current managed GUI run.
  - {{gtMethod:KGUiControlService class>>#uninstall}}
    Stop the service and clear request/readiness state idempotently.
  - {{gtMethod:KGUiControlService class>>#current}}
    Answer the installed service, if any.
  - {{gtMethod:KGUiControlService>>#start}}
    Prepare the spool, publish readiness, and start the serialized worker.
  - {{gtMethod:KGUiControlService>>#stop}}
    Stop the worker and remove stale request/readiness files.
  - {{gtMethod:KGUiControlService>>#handle:}}
    Validate and execute one schema-version-one request.
"
Class {
	#name : 'KGUiControlService',
	#superclass : 'Object',
	#instVars : [ 'root', 'requests', 'responses', 'runId', 'scene', 'worker', 'running' ],
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
	Current := self new start.
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
	scene := KGUiSceneGraph new
]

{ #category : 'private - spool' }
KGUiControlService >> deleteChildrenOf: aDirectory [
	aDirectory exists ifTrue: [
		aDirectory children do: [ :each | each isDirectory ifTrue: [ each deleteAll ] ifFalse: [ each delete ] ] ]
]

{ #category : 'private - spool' }
KGUiControlService >> writeJson: anObject atomicallyTo: destination [
	| temporary stream output |
	temporary := destination parent / ('.' , destination basename , '.tmp').
	temporary ensureDelete.
	output := STONJSON toString: anObject.
	stream := temporary writeStream.
	[ stream nextPutAll: output; flush ] ensure: [ stream close ].
	destination ensureDelete.
	temporary renameTo: destination basename
]

{ #category : 'public - lifecycle' }
KGUiControlService >> start [
	<return: #KGUiControlService>
	running ifTrue: [ ^ self ].
	runId := Smalltalk os environment at: 'KLIBGEN_RUN_ID' ifAbsent: [ '' ].
	root := (Smalltalk os environment at: 'TMPDIR') asFileReference / 'ui-control'.
	requests := root / 'requests'.
	responses := root / 'responses'.
	requests ensureCreateDirectory.
	responses ensureCreateDirectory.
	self deleteChildrenOf: requests; deleteChildrenOf: responses.
	self writeJson: (OrderedDictionary new
		at: 'schemaVersion' put: 1;
		at: 'runId' put: runId;
		at: 'ready' put: true;
		yourself) atomicallyTo: root / 'ready.json'.
	running := true.
	worker := [ self workerLoop ] forkAt: Processor userBackgroundPriority.
	^ self
]

{ #category : 'public - lifecycle' }
KGUiControlService >> stop [
	<return: #KGUiControlService>
	running := false.
	worker ifNotNil: [ worker terminate ].
	worker := nil.
	requests ifNotNil: [ self deleteChildrenOf: requests ].
	root ifNotNil: [ (root / 'ready.json') ensureDelete ].
	^ self
]

{ #category : 'private - spool' }
KGUiControlService >> workerLoop [
	[ running ] whileTrue: [
		| files |
		files := requests children select: [ :each | each extension = 'json' ].
		files sorted do: [ :requestFile | self processFile: requestFile ].
		(Delay forMilliseconds: 25) wait ]
]

{ #category : 'private - spool' }
KGUiControlService >> processFile: requestFile [
	| request requestId operation response |
	requestId := requestFile basenameWithoutExtension.
	operation := 'unknown'.
	response := [
		request := STONJSON fromString: requestFile contents.
		requestId := request at: 'requestId' ifAbsent: [ requestId ].
		operation := request at: 'operation' ifAbsent: [ operation ].
		self handle: request ]
		on: Exception
		do: [ :error | self failureFor: error requestId: requestId operation: operation ].
	[ [ self writeJson: response atomicallyTo: responses / (requestId , '.json') ]
		on: Exception
		do: [ :serializationError |
			self writeJson: (self failureFor: serializationError requestId: requestId operation: operation)
				atomicallyTo: responses / (requestId , '.json') ] ]
		ensure: [ requestFile ensureDelete ]
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
		at: 'runId' put: runId;
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
		at: 'runId' put: runId;
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
	(aRequest at: 'runId' ifAbsent: [ '' ]) = runId ifFalse: [ self error: 'UI control run mismatch' ].
	(aRequest at: 'deadlineUnixMs' ifAbsent: [ 0 ]) < (DateAndTime now asUnixTime * 1000)
		ifTrue: [ self error: 'expired UI control request' ].
	operation := aRequest at: 'operation' ifAbsent: [ self error: 'request is missing operation' ].
	data := self dispatch: operation request: aRequest.
	^ self successFor: aRequest data: data
]

{ #category : 'private - requests' }
KGUiControlService >> dispatch: operation request: aRequest [
	operation = 'ui.status' ifTrue: [ ^ OrderedDictionary new at: 'ready' put: true; at: 'runId' put: runId; yourself ].
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
