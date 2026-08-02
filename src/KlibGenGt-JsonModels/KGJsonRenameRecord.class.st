"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `RenameRecord`.

- Slots
  - `source` (`#String`, `accessing`) - Value of JSON field `from`.
  - `target` (`#String`, `accessing`) - Value of JSON field `to`.
- Public API
  - {{gtMethod:KGJsonRenameRecord>>#source}}
    Answer the immutable `source` field value.
  - {{gtMethod:KGJsonRenameRecord>>#target}}
    Answer the immutable `target` field value."
Class {
	#name : 'KGJsonRenameRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'source',
		'target'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonRenameRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonRenameRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('from' 'source' true #(#string)).
		#('to' 'target' true #(#string)) }
]

{ #category : 'json schema' }
KGJsonRenameRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonRenameRecord >> source [
	<return: #String>
	^ self defensiveJsonValue: source
]

{ #category : 'accessing' }
KGJsonRenameRecord >> target [
	<return: #String>
	^ self defensiveJsonValue: target
]
