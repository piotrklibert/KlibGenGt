"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `InventoryTargetRecord`.

- Slots
  - `name` (`#String`, `accessing`) - Value of JSON field `name`.
  - `outputKey` (`#String`, `accessing`) - Value of JSON field `outputKey`.
  - `steps` (`#(Array<KGJsonInventoryStepRecord>)`, `accessing`) - Value of JSON field `steps`.
- Public API
  - {{gtMethod:KGJsonInventoryTargetRecord>>#name}}
    Answer the immutable `name` field value.
  - {{gtMethod:KGJsonInventoryTargetRecord>>#outputKey}}
    Answer the immutable `outputKey` field value.
  - {{gtMethod:KGJsonInventoryTargetRecord>>#steps}}
    Answer the immutable `steps` field value."
Class {
	#name : 'KGJsonInventoryTargetRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'name',
		'outputKey',
		'steps'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonInventoryTargetRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonInventoryTargetRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('name' 'name' true #(#string)).
		#('outputKey' 'outputKey' true #(#string)).
		#('steps' 'steps' true #(#array #(#model #KGJsonInventoryStepRecord))) }
]

{ #category : 'json schema' }
KGJsonInventoryTargetRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonInventoryTargetRecord >> name [
	<return: #String>
	^ self defensiveJsonValue: name
]

{ #category : 'accessing' }
KGJsonInventoryTargetRecord >> outputKey [
	<return: #String>
	^ self defensiveJsonValue: outputKey
]

{ #category : 'accessing' }
KGJsonInventoryTargetRecord >> steps [
	<return: #(Array<KGJsonInventoryStepRecord>)>
	^ self defensiveJsonValue: steps
]
