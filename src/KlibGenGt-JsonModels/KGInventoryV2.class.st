"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `InventoryV2`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `operation` (`#String`, `accessing`) - Value of JSON field `operation`.
  - `generatedAt` (`#String`, `accessing`) - Value of JSON field `generatedAt`.
  - `nodes` (`#(Array<KGJsonInventoryNodeRecord>)`, `accessing`) - Value of JSON field `nodes`.
  - `edges` (`#(Array<KGJsonInventoryEdgeRecord>)`, `accessing`) - Value of JSON field `edges`.
  - `warnings` (`#(Array<String>)`, `accessing`) - Value of JSON field `warnings`.
  - `stateRoot` (`#String`, `accessing`) - Value of JSON field `stateRoot`.
  - `recipes` (`#(Array<KGJsonInventoryRecipeRecord>)`, `accessing`) - Value of JSON field `recipes`.
  - `targets` (`#(Array<KGJsonInventoryTargetRecord>)`, `accessing`) - Value of JSON field `targets`.
  - `artifacts` (`#(Array<(KGArtifactV1 | KGJsonInvalidArtifactRecord)>)`, `accessing`) - Value of JSON field `artifacts`.
  - `references` (`#(Array<(KGReferenceV1 | KGJsonMalformedRecord)>)`, `accessing`) - Value of JSON field `references`.
  - `workspaces` (`#(Array<(KGWorkspaceV1 | KGJsonMalformedRecord)>)`, `accessing`) - Value of JSON field `workspaces`.
  - `stagingAreas` (`#(Array<(KGStagingV1 | KGJsonMalformedRecord)>)`, `accessing`) - Value of JSON field `stagingAreas`.
  - `activeSessions` (`#(Array<(KGSessionV1 | KGJsonMalformedRecord)>)`, `accessing`) - Value of JSON field `activeSessions`.
  - `statuses` (`#(Array<(KGBuildStatusV1 | KGJsonMalformedRecord)>)`, `accessing`) - Value of JSON field `statuses`.
  - `locks` (`#(Array<String>)`, `accessing`) - Value of JSON field `locks`.
  - `storage` (`#KGJsonStorageRecord`, `accessing`) - Value of JSON field `storage`.
- Public API
  - {{gtMethod:KGInventoryV2>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGInventoryV2>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGInventoryV2>>#operation}}
    Answer the immutable `operation` field value.
  - {{gtMethod:KGInventoryV2>>#generatedAt}}
    Answer the immutable `generatedAt` field value.
  - {{gtMethod:KGInventoryV2>>#nodes}}
    Answer the immutable `nodes` field value.
  - {{gtMethod:KGInventoryV2>>#edges}}
    Answer the immutable `edges` field value.
  - {{gtMethod:KGInventoryV2>>#warnings}}
    Answer the immutable `warnings` field value.
  - {{gtMethod:KGInventoryV2>>#stateRoot}}
    Answer the immutable `stateRoot` field value.
  - {{gtMethod:KGInventoryV2>>#recipes}}
    Answer the immutable `recipes` field value.
  - {{gtMethod:KGInventoryV2>>#targets}}
    Answer the immutable `targets` field value.
  - {{gtMethod:KGInventoryV2>>#artifacts}}
    Answer the immutable `artifacts` field value.
  - {{gtMethod:KGInventoryV2>>#references}}
    Answer the immutable `references` field value.
  - {{gtMethod:KGInventoryV2>>#workspaces}}
    Answer the immutable `workspaces` field value.
  - {{gtMethod:KGInventoryV2>>#stagingAreas}}
    Answer the immutable `stagingAreas` field value.
  - {{gtMethod:KGInventoryV2>>#activeSessions}}
    Answer the immutable `activeSessions` field value.
  - {{gtMethod:KGInventoryV2>>#statuses}}
    Answer the immutable `statuses` field value.
  - {{gtMethod:KGInventoryV2>>#locks}}
    Answer the immutable `locks` field value.
  - {{gtMethod:KGInventoryV2>>#storage}}
    Answer the immutable `storage` field value.
"
Class {
	#name : 'KGInventoryV2',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'operation',
		'generatedAt',
		'nodes',
		'edges',
		'warnings',
		'stateRoot',
		'recipes',
		'targets',
		'artifacts',
		'references',
		'workspaces',
		'stagingAreas',
		'activeSessions',
		'statuses',
		'locks',
		'storage'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGInventoryV2 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGInventoryV2 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.inventory/2'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(2))).
		#('operation' 'operation' true #(#literal #('inventory'))).
		#('generatedAt' 'generatedAt' true #(#string)).
		#('nodes' 'nodes' true #(#array #(#model #KGJsonInventoryNodeRecord))).
		#('edges' 'edges' true #(#array #(#model #KGJsonInventoryEdgeRecord))).
		#('warnings' 'warnings' true #(#array #(#string))).
		#('stateRoot' 'stateRoot' true #(#string)).
		#('recipes' 'recipes' true #(#array #(#model #KGJsonInventoryRecipeRecord))).
		#('targets' 'targets' true #(#array #(#model #KGJsonInventoryTargetRecord))).
		#('artifacts' 'artifacts' true #(#array #(#union #(#(#model #KGArtifactV1) #(#model #KGJsonInvalidArtifactRecord))))).
		#('references' 'references' true #(#array #(#union #(#(#model #KGReferenceV1) #(#model #KGJsonMalformedRecord))))).
		#('workspaces' 'workspaces' true #(#array #(#union #(#(#model #KGWorkspaceV1) #(#model #KGJsonMalformedRecord))))).
		#('stagingAreas' 'stagingAreas' true #(#array #(#union #(#(#model #KGStagingV1) #(#model #KGJsonMalformedRecord))))).
		#('activeSessions' 'activeSessions' true #(#array #(#union #(#(#model #KGSessionV1) #(#model #KGJsonMalformedRecord))))).
		#('statuses' 'statuses' true #(#array #(#union #(#(#model #KGBuildStatusV1) #(#model #KGJsonMalformedRecord))))).
		#('locks' 'locks' true #(#array #(#string))).
		#('storage' 'storage' true #(#model #KGJsonStorageRecord)) }
]

{ #category : 'json schema' }
KGInventoryV2 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.inventory/2'
]

{ #category : 'accessing' }
KGInventoryV2 >> activeSessions [
	<return: #(Array<(KGSessionV1 | KGJsonMalformedRecord)>)>
	^ self defensiveJsonValue: activeSessions
]

{ #category : 'accessing' }
KGInventoryV2 >> artifacts [
	<return: #(Array<(KGArtifactV1 | KGJsonInvalidArtifactRecord)>)>
	^ self defensiveJsonValue: artifacts
]

{ #category : 'accessing' }
KGInventoryV2 >> edges [
	<return: #(Array<KGJsonInventoryEdgeRecord>)>
	^ self defensiveJsonValue: edges
]

{ #category : 'accessing' }
KGInventoryV2 >> generatedAt [
	<return: #String>
	^ self defensiveJsonValue: generatedAt
]

{ #category : 'accessing' }
KGInventoryV2 >> locks [
	<return: #(Array<String>)>
	^ self defensiveJsonValue: locks
]

{ #category : 'accessing' }
KGInventoryV2 >> nodes [
	<return: #(Array<KGJsonInventoryNodeRecord>)>
	^ self defensiveJsonValue: nodes
]

{ #category : 'accessing' }
KGInventoryV2 >> operation [
	<return: #String>
	^ self defensiveJsonValue: operation
]

{ #category : 'accessing' }
KGInventoryV2 >> recipes [
	<return: #(Array<KGJsonInventoryRecipeRecord>)>
	^ self defensiveJsonValue: recipes
]

{ #category : 'accessing' }
KGInventoryV2 >> references [
	<return: #(Array<(KGReferenceV1 | KGJsonMalformedRecord)>)>
	^ self defensiveJsonValue: references
]

{ #category : 'accessing' }
KGInventoryV2 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGInventoryV2 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGInventoryV2 >> stagingAreas [
	<return: #(Array<(KGStagingV1 | KGJsonMalformedRecord)>)>
	^ self defensiveJsonValue: stagingAreas
]

{ #category : 'accessing' }
KGInventoryV2 >> stateRoot [
	<return: #String>
	^ self defensiveJsonValue: stateRoot
]

{ #category : 'accessing' }
KGInventoryV2 >> statuses [
	<return: #(Array<(KGBuildStatusV1 | KGJsonMalformedRecord)>)>
	^ self defensiveJsonValue: statuses
]

{ #category : 'accessing' }
KGInventoryV2 >> storage [
	<return: #KGJsonStorageRecord>
	^ self defensiveJsonValue: storage
]

{ #category : 'accessing' }
KGInventoryV2 >> targets [
	<return: #(Array<KGJsonInventoryTargetRecord>)>
	^ self defensiveJsonValue: targets
]

{ #category : 'accessing' }
KGInventoryV2 >> warnings [
	<return: #(Array<String>)>
	^ self defensiveJsonValue: warnings
]

{ #category : 'accessing' }
KGInventoryV2 >> workspaces [
	<return: #(Array<(KGWorkspaceV1 | KGJsonMalformedRecord)>)>
	^ self defensiveJsonValue: workspaces
]
