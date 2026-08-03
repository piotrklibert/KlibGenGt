"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `StagingListV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `operation` (`#String`, `accessing`) - Value of JSON field `operation`.
  - `stagingAreas` (`#(Array<KGStagingV1>)`, `accessing`) - Value of JSON field `stagingAreas`.
- Public API
  - {{gtMethod:KGStagingListV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGStagingListV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGStagingListV1>>#operation}}
    Answer the immutable `operation` field value.
  - {{gtMethod:KGStagingListV1>>#stagingAreas}}
    Answer the immutable `stagingAreas` field value.
"
Class {
	#name : 'KGStagingListV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'operation',
		'stagingAreas'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGStagingListV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGStagingListV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.staging-list/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('operation' 'operation' true #(#string)).
		#('stagingAreas' 'stagingAreas' true #(#array #(#model #KGStagingV1))) }
]

{ #category : 'json schema' }
KGStagingListV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.staging-list/1'
]

{ #category : 'accessing' }
KGStagingListV1 >> operation [
	<return: #String>
	^ self defensiveJsonValue: operation
]

{ #category : 'accessing' }
KGStagingListV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGStagingListV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGStagingListV1 >> stagingAreas [
	<return: #(Array<KGStagingV1>)>
	^ self defensiveJsonValue: stagingAreas
]
