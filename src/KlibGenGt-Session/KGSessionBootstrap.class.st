"
Validate a session manifest, install capabilities, dispatch its entrypoint, and author lifecycle records.

- Slots
  - none
- Public API
  - {{gtMethod:KGSessionBootstrap class>>#runFromEnvironment}}
    Execute the `klibgen.session/1` manifest located by `KLIBGEN_SESSION_MANIFEST`.
  - {{gtMethod:KGSessionBootstrap class>>#runManifest:}}
    Validate and execute one manifest dictionary.
  - {{gtMethod:KGSessionBootstrap class>>#installManifest:}}
    Validate provenance and install capability variants without dispatching.
"
Class { #name : 'KGSessionBootstrap', #superclass : 'Object', #category : 'KlibGenGt-Session', #package : 'KlibGenGt-Session' }

{ #category : 'running' }
KGSessionBootstrap class >> runFromEnvironment [
	<return: #Nothing>
	| path manifest exitCode |
	path := Smalltalk os environment at: 'KLIBGEN_SESSION_MANIFEST' ifAbsent: [ self error: 'KLIBGEN_SESSION_MANIFEST is missing' ].
	manifest := STONJSON fromString: path asFileReference contents.
	exitCode := self runManifest: manifest.
	Smalltalk exit: exitCode
]

{ #category : 'running' }
KGSessionBootstrap class >> runManifest: manifest [
	<arg: #manifest type: #(Dictionary<String, Any>)> <return: #Integer>
	| paths request runner response state completion sessionId |
	self installManifest: manifest.
	sessionId := manifest at: 'sessionId'.
	paths := manifest at: 'paths'.
	KGAtomicJsonWriter write: (OrderedDictionary new at: 'schema' put: 'klibgen.session-ready/1'; at: 'sessionId' put: sessionId; at: 'ready' put: true; yourself) to: (paths at: 'ready').
	request := STONJSON fromString: (paths at: 'request') asFileReference contents.
	runner := Smalltalk at: #KGToolRunner.
	response := runner new run: request.
	KGAtomicJsonWriter write: response to: (paths at: 'result').
	state := (response at: 'ok') ifTrue: [ 'succeeded' ] ifFalse: [ 'failed' ].
	completion := OrderedDictionary new at: 'schema' put: 'klibgen.session-completion/1'; at: 'sessionId' put: sessionId; at: 'state' put: state; at: 'ok' put: (response at: 'ok'); yourself.
	KGAtomicJsonWriter write: completion to: (paths at: 'completion').
	^ (response at: 'ok') ifTrue: [ 0 ] ifFalse: [ 1 ]
]

{ #category : 'installation' }
KGSessionBootstrap class >> installManifest: manifest [
	<arg: #manifest type: #(Dictionary<String, Any>)> <return: #KGSession>
	| preset source persistence |
	(manifest at: 'schema' ifAbsent: [ '' ]) = 'klibgen.session/1' ifFalse: [ self error: 'Unsupported session manifest schema' ].
	KGBuildProvenance verifyProjectKey: (manifest at: 'projectKey').
	preset := manifest at: 'preset'.
	source := self sourceChangesNamed: (preset at: 'sourceChanges').
	persistence := self persistenceNamed: (preset at: 'persistence').
	KGSession reset.
	^ KGSession installManifest: manifest sourceChanges: source persistence: persistence
]

{ #category : 'private - capabilities' }
KGSessionBootstrap class >> persistenceNamed: aString [
	aString = 'discard' ifTrue: [ ^ KGDiscardPersistence new ].
	aString = 'workspace' ifTrue: [ ^ KGWorkspacePersistence new ].
	self error: 'Unknown persistence capability: ', aString
]

{ #category : 'private - capabilities' }
KGSessionBootstrap class >> sourceChangesNamed: aString [
	aString = 'disabled' ifTrue: [ ^ KGDisabledSourceChanges new ].
	aString = 'staged' ifTrue: [ ^ KGStagedSourceChanges new ].
	aString = 'interactive' ifTrue: [ ^ KGInteractiveSourceChanges new ].
	self error: 'Unknown source capability: ', aString
]
