"
SUnit coverage for generated v0.2 JSON records and named-schema dispatch.

- Slots
  - none
- Public API
  - none; test selectors document generated JSON model contracts.
"
Class {
	#name : 'KGJsonModelsTest',
	#superclass : 'TestCase',
	#category : 'KlibGenGt-Tests',
	#package : 'KlibGenGt-Tests'
}

{ #category : 'private - fixtures' }
KGJsonModelsTest >> inventoryDictionary [
	<return: #(Dictionary<String, Any>)>
	^ OrderedDictionary new
		at: 'schema' put: 'klibgen.inventory/2';
		at: 'schemaVersion' put: 2;
		at: 'operation' put: 'inventory';
		at: 'generatedAt' put: '2026-08-03T10:00:00+00:00';
		at: 'nodes' put: #();
		at: 'edges' put: #();
		at: 'warnings' put: #('first');
		at: 'stateRoot' put: '/state/v2';
		at: 'recipes' put: #();
		at: 'targets' put: #();
		at: 'artifacts' put: #();
		at: 'references' put: { Dictionary new at: 'path' put: '/bad.json'; at: 'malformed' put: true; at: 'error' put: 'bad JSON'; yourself };
		at: 'workspaces' put: #();
		at: 'stagingAreas' put: #();
		at: 'activeSessions' put: #();
		at: 'statuses' put: #();
		at: 'locks' put: #();
		at: 'storage' put: (Dictionary new at: 'logicalBytes' put: 0; at: 'allocatedBytes' put: 0; at: 'fileCount' put: 0; yourself);
		yourself
]

{ #category : 'tests' }
KGJsonModelsTest >> testGeneratedRecordRoundTripsAndProtectsCollections [
	| model warnings encoded |
	model := KGJsonModelRegistry parseDictionary: self inventoryDictionary.
	self assert: model class equals: KGInventoryV2.
	encoded := model asDictionary.
	self assert: (KGInventoryV2 fromJson: model asJson) asDictionary equals: encoded.
	warnings := model warnings.
	warnings at: 1 put: 'changed'.
	self assert: model warnings first equals: 'first'.
	self assert: model references first class equals: KGJsonMalformedRecord
]

{ #category : 'tests' }
KGJsonModelsTest >> testGuiCompletionRecordsPendingSourceChanges [
	| completion |
	completion := KGSessionCompletionV1 fromDictionary: (Dictionary new
		at: 'schema' put: 'klibgen.session-completion/1';
		at: 'sessionId' put: 'gui-session';
		at: 'state' put: 'saved';
		at: 'ok' put: true;
		at: 'sourceChangeCount' put: 2;
		yourself).
	self assert: completion sourceChangeCount equals: 2
]

{ #category : 'tests' }
KGJsonModelsTest >> testNamedRegistryContainsEveryV02Schema [
	self assert: KGJsonModelRegistry rebuild keys asSet equals: #(
		'klibgen.artifact-list/1'
		'klibgen.artifact-verification/1'
		'klibgen.artifact/1'
		'klibgen.build-result/1'
		'klibgen.build-status/1'
		'klibgen.doctor/1'
		'klibgen.gc-plan/1'
		'klibgen.inventory/2'
		'klibgen.measurement/1'
		'klibgen.recipe-catalog/1'
		'klibgen.refactoring-request/1'
		'klibgen.reference/1'
		'klibgen.resolved-recipe/1'
		'klibgen.session-completion/1'
		'klibgen.session-ready/1'
		'klibgen.session/1'
		'klibgen.source-lock/1'
		'klibgen.staging-list/1'
		'klibgen.staging-result/1'
		'klibgen.staging/1'
		'klibgen.status-list/1'
		'klibgen.workspace-reset/1'
		'klibgen.workspace-status/1'
		'klibgen.workspace/1') asSet
]

{ #category : 'tests' }
KGJsonModelsTest >> testValidationRejectsMissingUnknownAndWrongFields [
	self should: [ KGJsonModelRegistry parseDictionary: Dictionary new ] raise: Error.
	self should: [ KGJsonModelRegistry parseDictionary: (Dictionary new at: 'schema' put: 'klibgen.unknown/1'; yourself) ] raise: Error.
	self should: [ KGJsonStorageRecord fromDictionary: (Dictionary new at: 'logicalBytes' put: 0; at: 'allocatedBytes' put: 0; at: 'fileCount' put: 0; at: 'extra' put: true; yourself) ] raise: Error.
	self should: [ KGJsonStorageRecord fromDictionary: (Dictionary new at: 'logicalBytes' put: -1; at: 'allocatedBytes' put: 0; at: 'fileCount' put: 0; yourself) ] raise: Error.
	self should: [ KGInventoryV2 fromDictionary: (self inventoryDictionary at: 'schemaVersion' put: 1; yourself) ] raise: Error
]
