"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `PublishedArtifactRecord`.

- Slots
  - `role` (`#String`, `accessing`) - Value of JSON field `role`.
  - `path` (`#String`, `accessing`) - Value of JSON field `path`.
  - `reused` (`#Boolean`, `accessing`) - Value of JSON field `reused`.
- Public API
  - {{gtMethod:KGJsonPublishedArtifactRecord>>#role}}
    Answer the immutable `role` field value.
  - {{gtMethod:KGJsonPublishedArtifactRecord>>#path}}
    Answer the immutable `path` field value.
  - {{gtMethod:KGJsonPublishedArtifactRecord>>#reused}}
    Answer the immutable `reused` field value.
"
Class {
	#name : 'KGJsonPublishedArtifactRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'role',
		'path',
		'reused'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonPublishedArtifactRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonPublishedArtifactRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('role' 'role' true #(#string)).
		#('path' 'path' true #(#string)).
		#('reused' 'reused' true #(#boolean)) }
]

{ #category : 'json schema' }
KGJsonPublishedArtifactRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonPublishedArtifactRecord >> path [
	<return: #String>
	^ self defensiveJsonValue: path
]

{ #category : 'accessing' }
KGJsonPublishedArtifactRecord >> reused [
	<return: #Boolean>
	^ self defensiveJsonValue: reused
]

{ #category : 'accessing' }
KGJsonPublishedArtifactRecord >> role [
	<return: #String>
	^ self defensiveJsonValue: role
]
