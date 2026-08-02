"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `MalformedRecord`.

- Slots
  - `path` (`#String`, `accessing`) - Value of JSON field `path`.
  - `malformed` (`#Boolean`, `accessing`) - Value of JSON field `malformed`.
  - `error` (`#String`, `accessing`) - Value of JSON field `error`.
- Public API
  - {{gtMethod:KGJsonMalformedRecord>>#path}}
    Answer the immutable `path` field value.
  - {{gtMethod:KGJsonMalformedRecord>>#malformed}}
    Answer the immutable `malformed` field value.
  - {{gtMethod:KGJsonMalformedRecord>>#error}}
    Answer the immutable `error` field value."
Class {
	#name : 'KGJsonMalformedRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'path',
		'malformed',
		'error'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonMalformedRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonMalformedRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('path' 'path' true #(#string)).
		#('malformed' 'malformed' true #(#literal #(true))).
		#('error' 'error' true #(#string)) }
]

{ #category : 'json schema' }
KGJsonMalformedRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonMalformedRecord >> path [
	<return: #String>
	^ self defensiveJsonValue: path
]

{ #category : 'accessing' }
KGJsonMalformedRecord >> malformed [
	<return: #Boolean>
	^ self defensiveJsonValue: malformed
]

{ #category : 'accessing' }
KGJsonMalformedRecord >> error [
	<return: #String>
	^ self defensiveJsonValue: error
]
