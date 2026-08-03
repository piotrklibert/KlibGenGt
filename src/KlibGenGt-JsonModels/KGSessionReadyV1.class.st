"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `SessionReadyV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#(Integer | UndefinedObject)`, `accessing`) - Value of JSON field `schemaVersion`.
  - `sessionId` (`#String`, `accessing`) - Value of JSON field `sessionId`.
  - `ready` (`#Boolean`, `accessing`) - Value of JSON field `ready`.
- Public API
  - {{gtMethod:KGSessionReadyV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGSessionReadyV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGSessionReadyV1>>#sessionId}}
    Answer the immutable `sessionId` field value.
  - {{gtMethod:KGSessionReadyV1>>#ready}}
    Answer the immutable `ready` field value.
"
Class {
	#name : 'KGSessionReadyV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'sessionId',
		'ready'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGSessionReadyV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGSessionReadyV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.session-ready/1'))).
		#('schemaVersion' 'schemaVersion' false #(#union #(#(#literal #(1)) #(#nil)))).
		#('sessionId' 'sessionId' true #(#string)).
		#('ready' 'ready' true #(#literal #(true))) }
]

{ #category : 'json schema' }
KGSessionReadyV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.session-ready/1'
]

{ #category : 'accessing' }
KGSessionReadyV1 >> ready [
	<return: #Boolean>
	^ self defensiveJsonValue: ready
]

{ #category : 'accessing' }
KGSessionReadyV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGSessionReadyV1 >> schemaVersion [
	<return: #(Integer | UndefinedObject)>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGSessionReadyV1 >> sessionId [
	<return: #String>
	^ self defensiveJsonValue: sessionId
]
