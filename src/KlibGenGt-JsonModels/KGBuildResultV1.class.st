"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `BuildResultV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `operation` (`#String`, `accessing`) - Value of JSON field `operation`.
  - `target` (`#String`, `accessing`) - Value of JSON field `target`.
  - `outputKey` (`#String`, `accessing`) - Value of JSON field `outputKey`.
  - `artifacts` (`#(Array<KGJsonPublishedArtifactRecord>)`, `accessing`) - Value of JSON field `artifacts`.
  - `reference` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `reference`.
- Public API
  - {{gtMethod:KGBuildResultV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGBuildResultV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGBuildResultV1>>#operation}}
    Answer the immutable `operation` field value.
  - {{gtMethod:KGBuildResultV1>>#target}}
    Answer the immutable `target` field value.
  - {{gtMethod:KGBuildResultV1>>#outputKey}}
    Answer the immutable `outputKey` field value.
  - {{gtMethod:KGBuildResultV1>>#artifacts}}
    Answer the immutable `artifacts` field value.
  - {{gtMethod:KGBuildResultV1>>#reference}}
    Answer the immutable `reference` field value.
"
Class {
	#name : 'KGBuildResultV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'operation',
		'target',
		'outputKey',
		'artifacts',
		'reference'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGBuildResultV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGBuildResultV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.build-result/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('operation' 'operation' true #(#string)).
		#('target' 'target' true #(#string)).
		#('outputKey' 'outputKey' true #(#string)).
		#('artifacts' 'artifacts' true #(#array #(#model #KGJsonPublishedArtifactRecord))).
		#('reference' 'reference' false #(#union #(#(#string) #(#nil)))) }
]

{ #category : 'json schema' }
KGBuildResultV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.build-result/1'
]

{ #category : 'accessing' }
KGBuildResultV1 >> artifacts [
	<return: #(Array<KGJsonPublishedArtifactRecord>)>
	^ self defensiveJsonValue: artifacts
]

{ #category : 'accessing' }
KGBuildResultV1 >> operation [
	<return: #String>
	^ self defensiveJsonValue: operation
]

{ #category : 'accessing' }
KGBuildResultV1 >> outputKey [
	<return: #String>
	^ self defensiveJsonValue: outputKey
]

{ #category : 'accessing' }
KGBuildResultV1 >> reference [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: reference
]

{ #category : 'accessing' }
KGBuildResultV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGBuildResultV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGBuildResultV1 >> target [
	<return: #String>
	^ self defensiveJsonValue: target
]
