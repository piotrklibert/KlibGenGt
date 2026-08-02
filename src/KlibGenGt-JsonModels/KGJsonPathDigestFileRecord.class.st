"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `PathDigestFileRecord`.

- Slots
  - `path` (`#String`, `accessing`) - Value of JSON field `path`.
  - `kind` (`#String`, `accessing`) - Value of JSON field `kind`.
  - `target` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `target`.
  - `mode` (`#(Integer | UndefinedObject)`, `accessing`) - Value of JSON field `mode`.
  - `sha256` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `sha256`.
- Public API
  - {{gtMethod:KGJsonPathDigestFileRecord>>#path}}
    Answer the immutable `path` field value.
  - {{gtMethod:KGJsonPathDigestFileRecord>>#kind}}
    Answer the immutable `kind` field value.
  - {{gtMethod:KGJsonPathDigestFileRecord>>#target}}
    Answer the immutable `target` field value.
  - {{gtMethod:KGJsonPathDigestFileRecord>>#mode}}
    Answer the immutable `mode` field value.
  - {{gtMethod:KGJsonPathDigestFileRecord>>#sha256}}
    Answer the immutable `sha256` field value."
Class {
	#name : 'KGJsonPathDigestFileRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'path',
		'kind',
		'target',
		'mode',
		'sha256'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonPathDigestFileRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ true
]

{ #category : 'json schema' }
KGJsonPathDigestFileRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('path' 'path' true #(#string)).
		#('kind' 'kind' true #(#string)).
		#('target' 'target' false #(#union #(#(#string) #(#nil)))).
		#('mode' 'mode' false #(#union #(#(#integer) #(#nil)))).
		#('sha256' 'sha256' false #(#union #(#(#string) #(#nil)))) }
]

{ #category : 'json schema' }
KGJsonPathDigestFileRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonPathDigestFileRecord >> path [
	<return: #String>
	^ self defensiveJsonValue: path
]

{ #category : 'accessing' }
KGJsonPathDigestFileRecord >> kind [
	<return: #String>
	^ self defensiveJsonValue: kind
]

{ #category : 'accessing' }
KGJsonPathDigestFileRecord >> target [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: target
]

{ #category : 'accessing' }
KGJsonPathDigestFileRecord >> mode [
	<return: #(Integer | UndefinedObject)>
	^ self defensiveJsonValue: mode
]

{ #category : 'accessing' }
KGJsonPathDigestFileRecord >> sha256 [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: sha256
]
