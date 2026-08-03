"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `SessionCompletionV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#(Integer | UndefinedObject)`, `accessing`) - Value of JSON field `schemaVersion`.
  - `sessionId` (`#String`, `accessing`) - Value of JSON field `sessionId`.
  - `state` (`#String`, `accessing`) - Value of JSON field `state`.
  - `ok` (`#Boolean`, `accessing`) - Value of JSON field `ok`.
  - `exitCode` (`#(Integer | UndefinedObject)`, `accessing`) - Value of JSON field `exitCode`.
  - `error` (`#(KGJsonErrorRecord | UndefinedObject)`, `accessing`) - Value of JSON field `error`.
  - `sourceChangeCount` (`#(Integer | UndefinedObject)`, `accessing`) - Value of JSON field `sourceChangeCount`.
- Public API
  - {{gtMethod:KGSessionCompletionV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGSessionCompletionV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGSessionCompletionV1>>#sessionId}}
    Answer the immutable `sessionId` field value.
  - {{gtMethod:KGSessionCompletionV1>>#state}}
    Answer the immutable `state` field value.
  - {{gtMethod:KGSessionCompletionV1>>#ok}}
    Answer the immutable `ok` field value.
  - {{gtMethod:KGSessionCompletionV1>>#exitCode}}
    Answer the immutable `exitCode` field value.
  - {{gtMethod:KGSessionCompletionV1>>#error}}
    Answer the immutable `error` field value.
  - {{gtMethod:KGSessionCompletionV1>>#sourceChangeCount}}
    Answer the immutable `sourceChangeCount` field value."
Class {
	#name : 'KGSessionCompletionV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'sessionId',
		'state',
		'ok',
		'exitCode',
		'error',
		'sourceChangeCount'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGSessionCompletionV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGSessionCompletionV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.session-completion/1'))).
		#('schemaVersion' 'schemaVersion' false #(#union #(#(#literal #(1)) #(#nil)))).
		#('sessionId' 'sessionId' true #(#string)).
		#('state' 'state' true #(#literal #('succeeded' 'failed' 'saved' 'discarded' 'cancelled' 'abnormal'))).
		#('ok' 'ok' true #(#boolean)).
		#('exitCode' 'exitCode' false #(#union #(#(#integer) #(#nil)))).
		#('error' 'error' false #(#union #(#(#model #KGJsonErrorRecord) #(#nil)))).
		#('sourceChangeCount' 'sourceChangeCount' false #(#constrained #(#union #(#(#integer) #(#nil))) #(#(#ge 0)))) }
]

{ #category : 'json schema' }
KGSessionCompletionV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.session-completion/1'
]

{ #category : 'accessing' }
KGSessionCompletionV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGSessionCompletionV1 >> schemaVersion [
	<return: #(Integer | UndefinedObject)>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGSessionCompletionV1 >> sessionId [
	<return: #String>
	^ self defensiveJsonValue: sessionId
]

{ #category : 'accessing' }
KGSessionCompletionV1 >> state [
	<return: #String>
	^ self defensiveJsonValue: state
]

{ #category : 'accessing' }
KGSessionCompletionV1 >> ok [
	<return: #Boolean>
	^ self defensiveJsonValue: ok
]

{ #category : 'accessing' }
KGSessionCompletionV1 >> exitCode [
	<return: #(Integer | UndefinedObject)>
	^ self defensiveJsonValue: exitCode
]

{ #category : 'accessing' }
KGSessionCompletionV1 >> error [
	<return: #(KGJsonErrorRecord | UndefinedObject)>
	^ self defensiveJsonValue: error
]

{ #category : 'accessing' }
KGSessionCompletionV1 >> sourceChangeCount [
	<return: #(Integer | UndefinedObject)>
	^ self defensiveJsonValue: sourceChangeCount
]
