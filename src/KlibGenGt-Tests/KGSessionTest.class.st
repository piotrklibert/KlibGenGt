"
SUnit coverage for v0.2 session capabilities and registered tool dispatch.

- Slots
  - none
- Public API
  - none; test selectors document session and registry contracts.
"
Class { #name : 'KGSessionTest', #superclass : 'TestCase', #category : 'KlibGenGt-Tests', #package : 'KlibGenGt-Tests' }

{ #category : 'running' }
KGSessionTest >> tearDown [
	KGSession reset. KGToolRegistry resetDefault. super tearDown
]

{ #category : 'tests' }
KGSessionTest >> testDisabledCapabilitiesEnforceReadOnlyDiscardPolicy [
	| session |
	KGSession reset.
	session := KGSession installManifest: (Dictionary new
		at: 'schema' put: 'klibgen.session/1';
		at: 'schemaVersion' put: 1;
		at: 'sessionId' put: 'test';
		at: 'projectKey' put: 'test-project';
		at: 'preset' put: (Dictionary new at: 'name' put: 'cli'; at: 'frontend' put: 'headless'; at: 'sourceChanges' put: 'disabled'; at: 'persistence' put: 'discard'; yourself);
		at: 'paths' put: (Dictionary new at: 'completion' put: 'completion.json'; yourself);
		yourself) sourceChanges: KGDisabledSourceChanges new persistence: KGDiscardPersistence new.
	self deny: session sourceChanges available.
	self assert: session sourceChanges changeCount equals: 0.
	self should: [ session sourceChanges exportChanges ] raise: Error.
	self should: [ session sourceChanges promoteChanges ] raise: Error.
	self should: [ session persistence save ] raise: Error.
	self assert: session persistence discard equals: 'discarded'
]

{ #category : 'tests' }
KGSessionTest >> testStagedAndInteractiveCapabilitiesShareNamedStagingImplementation [
	self assert: KGStagedSourceChanges superclass identicalTo: KGStagingSourceChanges.
	self assert: KGInteractiveSourceChanges superclass identicalTo: KGStagingSourceChanges
]

{ #category : 'tests' }
KGSessionTest >> testStagingRequestEnvelopeIsSessionScopedAndBounded [
	| capability envelope manifest |
	manifest := KGSessionV1 fromDictionary: (Dictionary new
		at: 'schema' put: 'klibgen.session/1';
		at: 'schemaVersion' put: 1;
		at: 'sessionId' put: 'request-session';
		at: 'projectKey' put: 'test-project';
		at: 'preset' put: (Dictionary new at: 'name' put: 'agentic'; at: 'frontend' put: 'headless'; at: 'sourceChanges' put: 'staged'; at: 'persistence' put: 'discard'; yourself);
		at: 'paths' put: (Dictionary new at: 'completion' put: 'completion.json'; yourself);
		at: 'inputs' put: (Dictionary new at: 'stagingArea' put: 'fixture'; yourself);
		yourself).
	KGSession installManifest: manifest
		sourceChanges: (capability := KGStagingSourceChanges new initializeManifest: manifest)
		persistence: KGDiscardPersistence new.
	envelope := capability
		perform: #requestEnvelopeFor:requestId:
		withArguments: #('source.export' 'request-id').
	self assert: (envelope at: 'sessionId') equals: 'request-session'.
	self assert: (envelope at: 'stagingArea') equals: 'fixture'.
	self assert: (STONJSON toString: envelope) size < (64 * 1024)
]

{ #category : 'tests' }
KGSessionTest >> testRegistryContainsEveryCurrentStructuredTool [
	self assert: KGToolRegistry default identifiers equals: #('build-map.png' 'code.class' 'code.method' 'code.search' 'eval' 'lepiter.export' 'lepiter.search' 'test.all' 'test.run')
]

{ #category : 'tests' }
KGSessionTest >> testRegistryRejectsDuplicateAndUnknownIdentifiers [
	| registry registration |
	registry := KGToolRegistry new.
	registration := KGToolRegistration identifier: 'fixture' version: 1 frontends: #('headless') capabilities: #() handler: [ :request | request ].
	registry register: registration.
	self should: [ registry register: registration ] raise: Error.
	self should: [ registry at: 'missing' ] raise: Error
]
