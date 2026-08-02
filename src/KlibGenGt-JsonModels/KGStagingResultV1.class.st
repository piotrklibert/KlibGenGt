"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `StagingResultV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `operation` (`#String`, `accessing`) - Value of JSON field `operation`.
  - `staging` (`#KGStagingV1`, `accessing`) - Value of JSON field `staging`.
  - `path` (`#String`, `accessing`) - Value of JSON field `path`.
  - `changes` (`#(KGJsonStagingChangesRecord | UndefinedObject)`, `accessing`) - Value of JSON field `changes`.
- Public API
  - {{gtMethod:KGStagingResultV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGStagingResultV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGStagingResultV1>>#operation}}
    Answer the immutable `operation` field value.
  - {{gtMethod:KGStagingResultV1>>#staging}}
    Answer the immutable `staging` field value.
  - {{gtMethod:KGStagingResultV1>>#path}}
    Answer the immutable `path` field value.
  - {{gtMethod:KGStagingResultV1>>#changes}}
    Answer the immutable `changes` field value."
Class {
	#name : 'KGStagingResultV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'operation',
		'staging',
		'path',
		'changes'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGStagingResultV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGStagingResultV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.staging-result/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('operation' 'operation' true #(#string)).
		#('staging' 'staging' true #(#model #KGStagingV1)).
		#('path' 'path' true #(#string)).
		#('changes' 'changes' false #(#union #(#(#model #KGJsonStagingChangesRecord) #(#nil)))) }
]

{ #category : 'json schema' }
KGStagingResultV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.staging-result/1'
]

{ #category : 'accessing' }
KGStagingResultV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGStagingResultV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGStagingResultV1 >> operation [
	<return: #String>
	^ self defensiveJsonValue: operation
]

{ #category : 'accessing' }
KGStagingResultV1 >> staging [
	<return: #KGStagingV1>
	^ self defensiveJsonValue: staging
]

{ #category : 'accessing' }
KGStagingResultV1 >> path [
	<return: #String>
	^ self defensiveJsonValue: path
]

{ #category : 'accessing' }
KGStagingResultV1 >> changes [
	<return: #(KGJsonStagingChangesRecord | UndefinedObject)>
	^ self defensiveJsonValue: changes
]
