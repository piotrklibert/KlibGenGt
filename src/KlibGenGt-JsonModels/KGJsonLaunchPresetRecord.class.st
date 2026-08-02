"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `LaunchPresetRecord`.

- Slots
  - `name` (`#String`, `accessing`) - Value of JSON field `name`.
  - `frontend` (`#String`, `accessing`) - Value of JSON field `frontend`.
  - `sourceChanges` (`#String`, `accessing`) - Value of JSON field `sourceChanges`.
  - `persistence` (`#String`, `accessing`) - Value of JSON field `persistence`.
  - `entrypoint` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `entrypoint`.
  - `inputs` (`#((Array<String>) | UndefinedObject)`, `accessing`) - Value of JSON field `inputs`.
  - `startMode` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `startMode`.
- Public API
  - {{gtMethod:KGJsonLaunchPresetRecord>>#name}}
    Answer the immutable `name` field value.
  - {{gtMethod:KGJsonLaunchPresetRecord>>#frontend}}
    Answer the immutable `frontend` field value.
  - {{gtMethod:KGJsonLaunchPresetRecord>>#sourceChanges}}
    Answer the immutable `sourceChanges` field value.
  - {{gtMethod:KGJsonLaunchPresetRecord>>#persistence}}
    Answer the immutable `persistence` field value.
  - {{gtMethod:KGJsonLaunchPresetRecord>>#entrypoint}}
    Answer the immutable `entrypoint` field value.
  - {{gtMethod:KGJsonLaunchPresetRecord>>#inputs}}
    Answer the immutable `inputs` field value.
  - {{gtMethod:KGJsonLaunchPresetRecord>>#startMode}}
    Answer the immutable `startMode` field value."
Class {
	#name : 'KGJsonLaunchPresetRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'name',
		'frontend',
		'sourceChanges',
		'persistence',
		'entrypoint',
		'inputs',
		'startMode'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonLaunchPresetRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ true
]

{ #category : 'json schema' }
KGJsonLaunchPresetRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('name' 'name' true #(#string)).
		#('frontend' 'frontend' true #(#string)).
		#('sourceChanges' 'sourceChanges' true #(#string)).
		#('persistence' 'persistence' true #(#string)).
		#('entrypoint' 'entrypoint' false #(#union #(#(#string) #(#nil)))).
		#('inputs' 'inputs' false #(#union #(#(#array #(#string)) #(#nil)))).
		#('startMode' 'startMode' false #(#union #(#(#string) #(#nil)))) }
]

{ #category : 'json schema' }
KGJsonLaunchPresetRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonLaunchPresetRecord >> name [
	<return: #String>
	^ self defensiveJsonValue: name
]

{ #category : 'accessing' }
KGJsonLaunchPresetRecord >> frontend [
	<return: #String>
	^ self defensiveJsonValue: frontend
]

{ #category : 'accessing' }
KGJsonLaunchPresetRecord >> sourceChanges [
	<return: #String>
	^ self defensiveJsonValue: sourceChanges
]

{ #category : 'accessing' }
KGJsonLaunchPresetRecord >> persistence [
	<return: #String>
	^ self defensiveJsonValue: persistence
]

{ #category : 'accessing' }
KGJsonLaunchPresetRecord >> entrypoint [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: entrypoint
]

{ #category : 'accessing' }
KGJsonLaunchPresetRecord >> inputs [
	<return: #((Array<String>) | UndefinedObject)>
	^ self defensiveJsonValue: inputs
]

{ #category : 'accessing' }
KGJsonLaunchPresetRecord >> startMode [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: startMode
]
