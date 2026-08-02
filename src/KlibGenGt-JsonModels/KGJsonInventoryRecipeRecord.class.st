"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `InventoryRecipeRecord`.

- Slots
  - `name` (`#String`, `accessing`) - Value of JSON field `name`.
  - `roles` (`#(Array<String>)`, `accessing`) - Value of JSON field `roles`.
- Public API
  - {{gtMethod:KGJsonInventoryRecipeRecord>>#name}}
    Answer the immutable `name` field value.
  - {{gtMethod:KGJsonInventoryRecipeRecord>>#roles}}
    Answer the immutable `roles` field value."
Class {
	#name : 'KGJsonInventoryRecipeRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'name',
		'roles'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonInventoryRecipeRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonInventoryRecipeRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('name' 'name' true #(#string)).
		#('roles' 'roles' true #(#array #(#string))) }
]

{ #category : 'json schema' }
KGJsonInventoryRecipeRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonInventoryRecipeRecord >> name [
	<return: #String>
	^ self defensiveJsonValue: name
]

{ #category : 'accessing' }
KGJsonInventoryRecipeRecord >> roles [
	<return: #(Array<String>)>
	^ self defensiveJsonValue: roles
]
