"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `InvalidArtifactRecord`.

- Slots
  - `path` (`#String`, `accessing`) - Value of JSON field `path`.
  - `valid` (`#Boolean`, `accessing`) - Value of JSON field `valid`.
  - `error` (`#String`, `accessing`) - Value of JSON field `error`.
  - `storage` (`#(KGJsonStorageRecord | UndefinedObject)`, `accessing`) - Value of JSON field `storage`.
- Public API
  - {{gtMethod:KGJsonInvalidArtifactRecord>>#path}}
    Answer the immutable `path` field value.
  - {{gtMethod:KGJsonInvalidArtifactRecord>>#valid}}
    Answer the immutable `valid` field value.
  - {{gtMethod:KGJsonInvalidArtifactRecord>>#error}}
    Answer the immutable `error` field value.
  - {{gtMethod:KGJsonInvalidArtifactRecord>>#storage}}
    Answer the immutable `storage` field value."
Class {
	#name : 'KGJsonInvalidArtifactRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'path',
		'valid',
		'error',
		'storage'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonInvalidArtifactRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ true
]

{ #category : 'json schema' }
KGJsonInvalidArtifactRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('path' 'path' true #(#string)).
		#('valid' 'valid' true #(#literal #(false))).
		#('error' 'error' true #(#string)).
		#('storage' 'storage' false #(#union #(#(#model #KGJsonStorageRecord) #(#nil)))) }
]

{ #category : 'json schema' }
KGJsonInvalidArtifactRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonInvalidArtifactRecord >> path [
	<return: #String>
	^ self defensiveJsonValue: path
]

{ #category : 'accessing' }
KGJsonInvalidArtifactRecord >> valid [
	<return: #Boolean>
	^ self defensiveJsonValue: valid
]

{ #category : 'accessing' }
KGJsonInvalidArtifactRecord >> error [
	<return: #String>
	^ self defensiveJsonValue: error
]

{ #category : 'accessing' }
KGJsonInvalidArtifactRecord >> storage [
	<return: #(KGJsonStorageRecord | UndefinedObject)>
	^ self defensiveJsonValue: storage
]
