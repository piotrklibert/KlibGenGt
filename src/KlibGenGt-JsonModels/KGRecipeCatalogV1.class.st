"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `RecipeCatalogV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `operation` (`#String`, `accessing`) - Value of JSON field `operation`.
  - `targets` (`#(Array<KGJsonRecipeCatalogTargetRecord>)`, `accessing`) - Value of JSON field `targets`.
- Public API
  - {{gtMethod:KGRecipeCatalogV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGRecipeCatalogV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGRecipeCatalogV1>>#operation}}
    Answer the immutable `operation` field value.
  - {{gtMethod:KGRecipeCatalogV1>>#targets}}
    Answer the immutable `targets` field value.
"
Class {
	#name : 'KGRecipeCatalogV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'operation',
		'targets'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGRecipeCatalogV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGRecipeCatalogV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.recipe-catalog/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('operation' 'operation' true #(#string)).
		#('targets' 'targets' true #(#array #(#model #KGJsonRecipeCatalogTargetRecord))) }
]

{ #category : 'json schema' }
KGRecipeCatalogV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.recipe-catalog/1'
]

{ #category : 'accessing' }
KGRecipeCatalogV1 >> operation [
	<return: #String>
	^ self defensiveJsonValue: operation
]

{ #category : 'accessing' }
KGRecipeCatalogV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGRecipeCatalogV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGRecipeCatalogV1 >> targets [
	<return: #(Array<KGJsonRecipeCatalogTargetRecord>)>
	^ self defensiveJsonValue: targets
]
