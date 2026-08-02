"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `SessionPathsRecord`.

- Slots
  - `request` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `request`.
  - `ready` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `ready`.
  - `completion` (`#String`, `accessing`) - Value of JSON field `completion`.
  - `result` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `result`.
  - `eventJournal` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `eventJournal`.
- Public API
  - {{gtMethod:KGJsonSessionPathsRecord>>#request}}
    Answer the immutable `request` field value.
  - {{gtMethod:KGJsonSessionPathsRecord>>#ready}}
    Answer the immutable `ready` field value.
  - {{gtMethod:KGJsonSessionPathsRecord>>#completion}}
    Answer the immutable `completion` field value.
  - {{gtMethod:KGJsonSessionPathsRecord>>#result}}
    Answer the immutable `result` field value.
  - {{gtMethod:KGJsonSessionPathsRecord>>#eventJournal}}
    Answer the immutable `eventJournal` field value."
Class {
	#name : 'KGJsonSessionPathsRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'request',
		'ready',
		'completion',
		'result',
		'eventJournal'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonSessionPathsRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ true
]

{ #category : 'json schema' }
KGJsonSessionPathsRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('request' 'request' false #(#union #(#(#string) #(#nil)))).
		#('ready' 'ready' false #(#union #(#(#string) #(#nil)))).
		#('completion' 'completion' true #(#string)).
		#('result' 'result' false #(#union #(#(#string) #(#nil)))).
		#('eventJournal' 'eventJournal' false #(#union #(#(#string) #(#nil)))) }
]

{ #category : 'json schema' }
KGJsonSessionPathsRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonSessionPathsRecord >> request [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: request
]

{ #category : 'accessing' }
KGJsonSessionPathsRecord >> ready [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: ready
]

{ #category : 'accessing' }
KGJsonSessionPathsRecord >> completion [
	<return: #String>
	^ self defensiveJsonValue: completion
]

{ #category : 'accessing' }
KGJsonSessionPathsRecord >> result [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: result
]

{ #category : 'accessing' }
KGJsonSessionPathsRecord >> eventJournal [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: eventJournal
]
