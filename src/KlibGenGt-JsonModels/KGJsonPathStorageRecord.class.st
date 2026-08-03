"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `PathStorageRecord`.

- Slots
  - `path` (`#String`, `accessing`) - Value of JSON field `path`.
  - `storage` (`#KGJsonStorageRecord`, `accessing`) - Value of JSON field `storage`.
- Public API
  - {{gtMethod:KGJsonPathStorageRecord>>#path}}
    Answer the immutable `path` field value.
  - {{gtMethod:KGJsonPathStorageRecord>>#storage}}
    Answer the immutable `storage` field value.
"
Class {
	#name : 'KGJsonPathStorageRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'path',
		'storage'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonPathStorageRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonPathStorageRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('path' 'path' true #(#string)).
		#('storage' 'storage' true #(#model #KGJsonStorageRecord)) }
]

{ #category : 'json schema' }
KGJsonPathStorageRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonPathStorageRecord >> path [
	<return: #String>
	^ self defensiveJsonValue: path
]

{ #category : 'accessing' }
KGJsonPathStorageRecord >> storage [
	<return: #KGJsonStorageRecord>
	^ self defensiveJsonValue: storage
]
