"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `SourceLockV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `sources` (`#(Array<(Dictionary<String, Any>)>)`, `accessing`) - Value of JSON field `sources`.
- Public API
  - {{gtMethod:KGSourceLockV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGSourceLockV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGSourceLockV1>>#sources}}
    Answer the immutable `sources` field value.
"
Class {
	#name : 'KGSourceLockV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'sources'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGSourceLockV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ true
]

{ #category : 'json schema' }
KGSourceLockV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.source-lock/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('sources' 'sources' true #(#array #(#dictionary #(#any)))) }
]

{ #category : 'json schema' }
KGSourceLockV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.source-lock/1'
]

{ #category : 'accessing' }
KGSourceLockV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGSourceLockV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGSourceLockV1 >> sources [
	<return: #(Array<(Dictionary<String, Any>)>)>
	^ self defensiveJsonValue: sources
]
