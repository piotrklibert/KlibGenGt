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
Class {
	#name : 'KGSessionBootstrap',
	#superclass : 'Object',
	#category : 'KlibGenGt-Session',
	#package : 'KlibGenGt-Session'
}

{ #category : 'installation' }
KGSessionBootstrap class >> installManifest: manifest [
	<arg: #manifest type: #(Dictionary<String, Any>)> <return: #KGSession>
	| typedManifest preset source persistence |
	typedManifest := KGJsonModelRegistry parseDictionary: manifest.
	(typedManifest isKindOf: KGSessionV1) ifFalse: [ self error: 'Unsupported session manifest schema' ].
	KGBuildProvenance verifyProjectKey: typedManifest projectKey.
	preset := typedManifest preset.
	source := self sourceChangesNamed: preset sourceChanges manifest: typedManifest.
	persistence := self persistenceNamed: preset persistence.
	KGSession reset.
	^ KGSession installManifest: typedManifest sourceChanges: source persistence: persistence
]

{ #category : 'private - capabilities' }
KGSessionBootstrap class >> persistenceNamed: aString [
	aString = 'discard' ifTrue: [ ^ KGDiscardPersistence new ].
	aString = 'workspace' ifTrue: [ ^ KGWorkspacePersistence new ].
	self error: 'Unknown persistence capability: ', aString
]

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
	| paths request runner response state completion session sessionId |
	session := self installManifest: manifest.
	sessionId := session id.
	paths := session manifest paths.
	KGAtomicJsonWriter
		write: (KGSessionReadyV1 fromDictionary: (OrderedDictionary new
			at: 'schema' put: 'klibgen.session-ready/1';
			at: 'sessionId' put: sessionId;
			at: 'ready' put: true;
			yourself))
		to: paths ready.
	request := STONJSON fromString: paths request asFileReference contents.
	runner := Smalltalk at: #KGToolRunner.
	response := runner new run: request.
	KGAtomicJsonWriter write: response to: paths result.
	state := (response at: 'ok') ifTrue: [ 'succeeded' ] ifFalse: [ 'failed' ].
	completion := KGSessionCompletionV1 fromDictionary: (OrderedDictionary new at: 'schema' put: 'klibgen.session-completion/1'; at: 'sessionId' put: sessionId; at: 'state' put: state; at: 'ok' put: (response at: 'ok'); at: 'sourceChangeCount' put: session sourceChanges changeCount; yourself).
	KGAtomicJsonWriter write: completion to: paths completion.
	^ (response at: 'ok') ifTrue: [ 0 ] ifFalse: [ 1 ]
]

{ #category : 'private - capabilities' }
KGSessionBootstrap class >> sourceChangesNamed: aString manifest: aManifest [
	<arg: #aString type: #String>
	<arg: #aManifest type: #KGSessionV1>
	<return: #Any>
	aString = 'disabled' ifTrue: [ ^ KGDisabledSourceChanges new ].
	aString = 'staged' ifTrue: [ ^ KGStagedSourceChanges new initializeManifest: aManifest ].
	aString = 'interactive' ifTrue: [ ^ KGInteractiveSourceChanges new initializeManifest: aManifest ].
	self error: 'Unknown source capability: ', aString
]
