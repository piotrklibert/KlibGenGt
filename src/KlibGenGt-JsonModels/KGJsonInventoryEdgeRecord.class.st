"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `InventoryEdgeRecord`.

- Slots
  - `id` (`#String`, `accessing`) - Value of JSON field `id`.
  - `kind` (`#String`, `accessing`) - Value of JSON field `kind`.
  - `source` (`#String`, `accessing`) - Value of JSON field `source`.
  - `target` (`#String`, `accessing`) - Value of JSON field `target`.
  - `characteristics` (`#(Dictionary<String, Any>)`, `accessing`) - Value of JSON field `characteristics`.
- Public API
  - {{gtMethod:KGJsonInventoryEdgeRecord>>#id}}
    Answer the immutable `id` field value.
  - {{gtMethod:KGJsonInventoryEdgeRecord>>#kind}}
    Answer the immutable `kind` field value.
  - {{gtMethod:KGJsonInventoryEdgeRecord>>#source}}
    Answer the immutable `source` field value.
  - {{gtMethod:KGJsonInventoryEdgeRecord>>#target}}
    Answer the immutable `target` field value.
  - {{gtMethod:KGJsonInventoryEdgeRecord>>#characteristics}}
    Answer the immutable `characteristics` field value."
Class {
	#name : 'KGJsonInventoryEdgeRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'id',
		'kind',
		'source',
		'target',
		'characteristics'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonInventoryEdgeRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonInventoryEdgeRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('id' 'id' true #(#string)).
		#('kind' 'kind' true #(#string)).
		#('source' 'source' true #(#string)).
		#('target' 'target' true #(#string)).
		#('characteristics' 'characteristics' true #(#dictionary #(#any))) }
]

{ #category : 'json schema' }
KGJsonInventoryEdgeRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonInventoryEdgeRecord >> id [
	<return: #String>
	^ self defensiveJsonValue: id
]

{ #category : 'accessing' }
KGJsonInventoryEdgeRecord >> kind [
	<return: #String>
	^ self defensiveJsonValue: kind
]

{ #category : 'accessing' }
KGJsonInventoryEdgeRecord >> source [
	<return: #String>
	^ self defensiveJsonValue: source
]

{ #category : 'accessing' }
KGJsonInventoryEdgeRecord >> target [
	<return: #String>
	^ self defensiveJsonValue: target
]

{ #category : 'accessing' }
KGJsonInventoryEdgeRecord >> characteristics [
	<return: #(Dictionary<String, Any>)>
	^ self defensiveJsonValue: characteristics
]
