"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `InventoryStepRecord`.

- Slots
  - `role` (`#String`, `accessing`) - Value of JSON field `role`.
  - `outputKey` (`#String`, `accessing`) - Value of JSON field `outputKey`.
  - `checkpoint` (`#String`, `accessing`) - Value of JSON field `checkpoint`.
- Public API
  - {{gtMethod:KGJsonInventoryStepRecord>>#role}}
    Answer the immutable `role` field value.
  - {{gtMethod:KGJsonInventoryStepRecord>>#outputKey}}
    Answer the immutable `outputKey` field value.
  - {{gtMethod:KGJsonInventoryStepRecord>>#checkpoint}}
    Answer the immutable `checkpoint` field value.
"
Class {
	#name : 'KGJsonInventoryStepRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'role',
		'outputKey',
		'checkpoint'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonInventoryStepRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonInventoryStepRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('role' 'role' true #(#string)).
		#('outputKey' 'outputKey' true #(#string)).
		#('checkpoint' 'checkpoint' true #(#literal #('none' 'artifact'))) }
]

{ #category : 'json schema' }
KGJsonInventoryStepRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonInventoryStepRecord >> checkpoint [
	<return: #String>
	^ self defensiveJsonValue: checkpoint
]

{ #category : 'accessing' }
KGJsonInventoryStepRecord >> outputKey [
	<return: #String>
	^ self defensiveJsonValue: outputKey
]

{ #category : 'accessing' }
KGJsonInventoryStepRecord >> role [
	<return: #String>
	^ self defensiveJsonValue: role
]
