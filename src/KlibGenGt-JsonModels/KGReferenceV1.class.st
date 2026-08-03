"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `ReferenceV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `name` (`#String`, `accessing`) - Value of JSON field `name`.
  - `artifactType` (`#String`, `accessing`) - Value of JSON field `artifactType`.
  - `outputKey` (`#String`, `accessing`) - Value of JSON field `outputKey`.
  - `artifactPath` (`#String`, `accessing`) - Value of JSON field `artifactPath`.
  - `producingRole` (`#String`, `accessing`) - Value of JSON field `producingRole`.
  - `path` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `path`.
  - `storage` (`#(KGJsonStorageRecord | UndefinedObject)`, `accessing`) - Value of JSON field `storage`.
- Public API
  - {{gtMethod:KGReferenceV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGReferenceV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGReferenceV1>>#name}}
    Answer the immutable `name` field value.
  - {{gtMethod:KGReferenceV1>>#artifactType}}
    Answer the immutable `artifactType` field value.
  - {{gtMethod:KGReferenceV1>>#outputKey}}
    Answer the immutable `outputKey` field value.
  - {{gtMethod:KGReferenceV1>>#artifactPath}}
    Answer the immutable `artifactPath` field value.
  - {{gtMethod:KGReferenceV1>>#producingRole}}
    Answer the immutable `producingRole` field value.
  - {{gtMethod:KGReferenceV1>>#path}}
    Answer the immutable `path` field value.
  - {{gtMethod:KGReferenceV1>>#storage}}
    Answer the immutable `storage` field value.
"
Class {
	#name : 'KGReferenceV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'name',
		'artifactType',
		'outputKey',
		'artifactPath',
		'producingRole',
		'path',
		'storage'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGReferenceV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ true
]

{ #category : 'json schema' }
KGReferenceV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.reference/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('name' 'name' true #(#string)).
		#('artifactType' 'artifactType' true #(#string)).
		#('outputKey' 'outputKey' true #(#string)).
		#('artifactPath' 'artifactPath' true #(#string)).
		#('producingRole' 'producingRole' true #(#string)).
		#('path' 'path' false #(#union #(#(#string) #(#nil)))).
		#('storage' 'storage' false #(#union #(#(#model #KGJsonStorageRecord) #(#nil)))) }
]

{ #category : 'json schema' }
KGReferenceV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.reference/1'
]

{ #category : 'accessing' }
KGReferenceV1 >> artifactPath [
	<return: #String>
	^ self defensiveJsonValue: artifactPath
]

{ #category : 'accessing' }
KGReferenceV1 >> artifactType [
	<return: #String>
	^ self defensiveJsonValue: artifactType
]

{ #category : 'accessing' }
KGReferenceV1 >> name [
	<return: #String>
	^ self defensiveJsonValue: name
]

{ #category : 'accessing' }
KGReferenceV1 >> outputKey [
	<return: #String>
	^ self defensiveJsonValue: outputKey
]

{ #category : 'accessing' }
KGReferenceV1 >> path [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: path
]

{ #category : 'accessing' }
KGReferenceV1 >> producingRole [
	<return: #String>
	^ self defensiveJsonValue: producingRole
]

{ #category : 'accessing' }
KGReferenceV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGReferenceV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGReferenceV1 >> storage [
	<return: #(KGJsonStorageRecord | UndefinedObject)>
	^ self defensiveJsonValue: storage
]
