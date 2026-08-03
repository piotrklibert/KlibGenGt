"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `RecipeCatalogTargetRecord`.

- Slots
  - `name` (`#String`, `accessing`) - Value of JSON field `name`.
  - `recipe` (`#String`, `accessing`) - Value of JSON field `recipe`.
  - `preset` (`#KGJsonLaunchPresetRecord`, `accessing`) - Value of JSON field `preset`.
  - `roles` (`#(Array<String>)`, `accessing`) - Value of JSON field `roles`.
- Public API
  - {{gtMethod:KGJsonRecipeCatalogTargetRecord>>#name}}
    Answer the immutable `name` field value.
  - {{gtMethod:KGJsonRecipeCatalogTargetRecord>>#recipe}}
    Answer the immutable `recipe` field value.
  - {{gtMethod:KGJsonRecipeCatalogTargetRecord>>#preset}}
    Answer the immutable `preset` field value.
  - {{gtMethod:KGJsonRecipeCatalogTargetRecord>>#roles}}
    Answer the immutable `roles` field value.
"
Class {
	#name : 'KGJsonRecipeCatalogTargetRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'name',
		'recipe',
		'preset',
		'roles'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonRecipeCatalogTargetRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonRecipeCatalogTargetRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('name' 'name' true #(#string)).
		#('recipe' 'recipe' true #(#string)).
		#('preset' 'preset' true #(#model #KGJsonLaunchPresetRecord)).
		#('roles' 'roles' true #(#array #(#string))) }
]

{ #category : 'json schema' }
KGJsonRecipeCatalogTargetRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonRecipeCatalogTargetRecord >> name [
	<return: #String>
	^ self defensiveJsonValue: name
]

{ #category : 'accessing' }
KGJsonRecipeCatalogTargetRecord >> preset [
	<return: #KGJsonLaunchPresetRecord>
	^ self defensiveJsonValue: preset
]

{ #category : 'accessing' }
KGJsonRecipeCatalogTargetRecord >> recipe [
	<return: #String>
	^ self defensiveJsonValue: recipe
]

{ #category : 'accessing' }
KGJsonRecipeCatalogTargetRecord >> roles [
	<return: #(Array<String>)>
	^ self defensiveJsonValue: roles
]
