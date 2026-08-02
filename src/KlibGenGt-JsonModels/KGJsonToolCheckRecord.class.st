"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `ToolCheckRecord`.

- Slots
  - `ok` (`#Boolean`, `accessing`) - Value of JSON field `ok`.
  - `name` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `name`.
  - `path` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `path`.
- Public API
  - {{gtMethod:KGJsonToolCheckRecord>>#ok}}
    Answer the immutable `ok` field value.
  - {{gtMethod:KGJsonToolCheckRecord>>#name}}
    Answer the immutable `name` field value.
  - {{gtMethod:KGJsonToolCheckRecord>>#path}}
    Answer the immutable `path` field value."
Class {
	#name : 'KGJsonToolCheckRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'ok',
		'name',
		'path'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonToolCheckRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonToolCheckRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('ok' 'ok' true #(#boolean)).
		#('name' 'name' false #(#union #(#(#string) #(#nil)))).
		#('path' 'path' false #(#union #(#(#string) #(#nil)))) }
]

{ #category : 'json schema' }
KGJsonToolCheckRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonToolCheckRecord >> ok [
	<return: #Boolean>
	^ self defensiveJsonValue: ok
]

{ #category : 'accessing' }
KGJsonToolCheckRecord >> name [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: name
]

{ #category : 'accessing' }
KGJsonToolCheckRecord >> path [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: path
]
