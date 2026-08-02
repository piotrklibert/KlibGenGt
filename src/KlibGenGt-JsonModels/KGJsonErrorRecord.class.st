"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `ErrorRecord`.

- Slots
  - `errorClass` (`#String`, `accessing`) - Value of JSON field `class`.
  - `message` (`#String`, `accessing`) - Value of JSON field `message`.
- Public API
  - {{gtMethod:KGJsonErrorRecord>>#errorClass}}
    Answer the immutable `errorClass` field value.
  - {{gtMethod:KGJsonErrorRecord>>#message}}
    Answer the immutable `message` field value."
Class {
	#name : 'KGJsonErrorRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'errorClass',
		'message'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonErrorRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonErrorRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('class' 'errorClass' true #(#string)).
		#('message' 'message' true #(#string)) }
]

{ #category : 'json schema' }
KGJsonErrorRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonErrorRecord >> errorClass [
	<return: #String>
	^ self defensiveJsonValue: errorClass
]

{ #category : 'accessing' }
KGJsonErrorRecord >> message [
	<return: #String>
	^ self defensiveJsonValue: message
]
