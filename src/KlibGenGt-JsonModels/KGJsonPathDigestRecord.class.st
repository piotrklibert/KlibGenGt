"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `PathDigestRecord`.

- Slots
  - `digest` (`#String`, `accessing`) - Value of JSON field `digest`.
  - `files` (`#(Array<KGJsonPathDigestFileRecord>)`, `accessing`) - Value of JSON field `files`.
- Public API
  - {{gtMethod:KGJsonPathDigestRecord>>#digest}}
    Answer the immutable `digest` field value.
  - {{gtMethod:KGJsonPathDigestRecord>>#files}}
    Answer the immutable `files` field value.
"
Class {
	#name : 'KGJsonPathDigestRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'digest',
		'files'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonPathDigestRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonPathDigestRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('digest' 'digest' true #(#string)).
		#('files' 'files' true #(#array #(#model #KGJsonPathDigestFileRecord))) }
]

{ #category : 'json schema' }
KGJsonPathDigestRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonPathDigestRecord >> digest [
	<return: #String>
	^ self defensiveJsonValue: digest
]

{ #category : 'accessing' }
KGJsonPathDigestRecord >> files [
	<return: #(Array<KGJsonPathDigestFileRecord>)>
	^ self defensiveJsonValue: files
]
