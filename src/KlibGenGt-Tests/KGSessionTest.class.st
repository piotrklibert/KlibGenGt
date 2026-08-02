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
	session := KGSession installManifest: (Dictionary new at: 'sessionId' put: 'test'; yourself) sourceChanges: KGDisabledSourceChanges new persistence: KGDiscardPersistence new.
	self deny: session sourceChanges available.
	self assert: session sourceChanges changeCount equals: 0.
	self should: [ session sourceChanges exportChanges ] raise: Error.
	self should: [ session persistence save ] raise: Error.
	self assert: session persistence discard equals: 'discarded'
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
