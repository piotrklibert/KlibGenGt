"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `PromotionRecord`.

- Slots
  - `ok` (`#Boolean`, `accessing`) - Value of JSON field `ok`.
  - `conflicts` (`#((Array<String>) | UndefinedObject)`, `accessing`) - Value of JSON field `conflicts`.
  - `changes` (`#(KGJsonStagingChangesRecord | UndefinedObject)`, `accessing`) - Value of JSON field `changes`.
- Public API
  - {{gtMethod:KGJsonPromotionRecord>>#ok}}
    Answer the immutable `ok` field value.
  - {{gtMethod:KGJsonPromotionRecord>>#conflicts}}
    Answer the immutable `conflicts` field value.
  - {{gtMethod:KGJsonPromotionRecord>>#changes}}
    Answer the immutable `changes` field value.
"
Class {
	#name : 'KGJsonPromotionRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'ok',
		'conflicts',
		'changes'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonPromotionRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ true
]

{ #category : 'json schema' }
KGJsonPromotionRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('ok' 'ok' true #(#boolean)).
		#('conflicts' 'conflicts' false #(#union #(#(#array #(#string)) #(#nil)))).
		#('changes' 'changes' false #(#union #(#(#model #KGJsonStagingChangesRecord) #(#nil)))) }
]

{ #category : 'json schema' }
KGJsonPromotionRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonPromotionRecord >> changes [
	<return: #(KGJsonStagingChangesRecord | UndefinedObject)>
	^ self defensiveJsonValue: changes
]

{ #category : 'accessing' }
KGJsonPromotionRecord >> conflicts [
	<return: #((Array<String>) | UndefinedObject)>
	^ self defensiveJsonValue: conflicts
]

{ #category : 'accessing' }
KGJsonPromotionRecord >> ok [
	<return: #Boolean>
	^ self defensiveJsonValue: ok
]
