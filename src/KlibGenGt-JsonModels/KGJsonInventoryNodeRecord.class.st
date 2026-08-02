"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `InventoryNodeRecord`.

- Slots
  - `id` (`#String`, `accessing`) - Value of JSON field `id`.
  - `kind` (`#String`, `accessing`) - Value of JSON field `kind`.
  - `label` (`#String`, `accessing`) - Value of JSON field `label`.
  - `status` (`#String`, `accessing`) - Value of JSON field `status`.
  - `characteristics` (`#(Dictionary<String, Any>)`, `accessing`) - Value of JSON field `characteristics`.
  - `logicalBytes` (`#Integer`, `accessing`) - Value of JSON field `logicalBytes`.
  - `allocatedBytes` (`#Integer`, `accessing`) - Value of JSON field `allocatedBytes`.
  - `fileCount` (`#Integer`, `accessing`) - Value of JSON field `fileCount`.
  - `path` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `path`.
- Public API
  - {{gtMethod:KGJsonInventoryNodeRecord>>#id}}
    Answer the immutable `id` field value.
  - {{gtMethod:KGJsonInventoryNodeRecord>>#kind}}
    Answer the immutable `kind` field value.
  - {{gtMethod:KGJsonInventoryNodeRecord>>#label}}
    Answer the immutable `label` field value.
  - {{gtMethod:KGJsonInventoryNodeRecord>>#status}}
    Answer the immutable `status` field value.
  - {{gtMethod:KGJsonInventoryNodeRecord>>#characteristics}}
    Answer the immutable `characteristics` field value.
  - {{gtMethod:KGJsonInventoryNodeRecord>>#logicalBytes}}
    Answer the immutable `logicalBytes` field value.
  - {{gtMethod:KGJsonInventoryNodeRecord>>#allocatedBytes}}
    Answer the immutable `allocatedBytes` field value.
  - {{gtMethod:KGJsonInventoryNodeRecord>>#fileCount}}
    Answer the immutable `fileCount` field value.
  - {{gtMethod:KGJsonInventoryNodeRecord>>#path}}
    Answer the immutable `path` field value."
Class {
	#name : 'KGJsonInventoryNodeRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'id',
		'kind',
		'label',
		'status',
		'characteristics',
		'logicalBytes',
		'allocatedBytes',
		'fileCount',
		'path'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonInventoryNodeRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ true
]

{ #category : 'json schema' }
KGJsonInventoryNodeRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('id' 'id' true #(#string)).
		#('kind' 'kind' true #(#literal #('target' 'step' 'artifact' 'reference' 'workspace' 'staging'))).
		#('label' 'label' true #(#string)).
		#('status' 'status' true #(#string)).
		#('characteristics' 'characteristics' true #(#dictionary #(#any))).
		#('logicalBytes' 'logicalBytes' true #(#constrained #(#integer) #(#(#ge 0)))).
		#('allocatedBytes' 'allocatedBytes' true #(#constrained #(#integer) #(#(#ge 0)))).
		#('fileCount' 'fileCount' true #(#constrained #(#integer) #(#(#ge 0)))).
		#('path' 'path' false #(#union #(#(#string) #(#nil)))) }
]

{ #category : 'json schema' }
KGJsonInventoryNodeRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonInventoryNodeRecord >> id [
	<return: #String>
	^ self defensiveJsonValue: id
]

{ #category : 'accessing' }
KGJsonInventoryNodeRecord >> kind [
	<return: #String>
	^ self defensiveJsonValue: kind
]

{ #category : 'accessing' }
KGJsonInventoryNodeRecord >> label [
	<return: #String>
	^ self defensiveJsonValue: label
]

{ #category : 'accessing' }
KGJsonInventoryNodeRecord >> status [
	<return: #String>
	^ self defensiveJsonValue: status
]

{ #category : 'accessing' }
KGJsonInventoryNodeRecord >> characteristics [
	<return: #(Dictionary<String, Any>)>
	^ self defensiveJsonValue: characteristics
]

{ #category : 'accessing' }
KGJsonInventoryNodeRecord >> logicalBytes [
	<return: #Integer>
	^ self defensiveJsonValue: logicalBytes
]

{ #category : 'accessing' }
KGJsonInventoryNodeRecord >> allocatedBytes [
	<return: #Integer>
	^ self defensiveJsonValue: allocatedBytes
]

{ #category : 'accessing' }
KGJsonInventoryNodeRecord >> fileCount [
	<return: #Integer>
	^ self defensiveJsonValue: fileCount
]

{ #category : 'accessing' }
KGJsonInventoryNodeRecord >> path [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: path
]
