"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `GcPlanV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `operation` (`#String`, `accessing`) - Value of JSON field `operation`.
  - `mode` (`#String`, `accessing`) - Value of JSON field `mode`.
  - `roots` (`#(Array<String>)`, `accessing`) - Value of JSON field `roots`.
  - `remove` (`#(Array<KGJsonPathStorageRecord>)`, `accessing`) - Value of JSON field `remove`.
  - `warnings` (`#(Array<String>)`, `accessing`) - Value of JSON field `warnings`.
  - `applied` (`#Boolean`, `accessing`) - Value of JSON field `applied`.
- Public API
  - {{gtMethod:KGGcPlanV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGGcPlanV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGGcPlanV1>>#operation}}
    Answer the immutable `operation` field value.
  - {{gtMethod:KGGcPlanV1>>#mode}}
    Answer the immutable `mode` field value.
  - {{gtMethod:KGGcPlanV1>>#roots}}
    Answer the immutable `roots` field value.
  - {{gtMethod:KGGcPlanV1>>#remove}}
    Answer the immutable `remove` field value.
  - {{gtMethod:KGGcPlanV1>>#warnings}}
    Answer the immutable `warnings` field value.
  - {{gtMethod:KGGcPlanV1>>#applied}}
    Answer the immutable `applied` field value."
Class {
	#name : 'KGGcPlanV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'operation',
		'mode',
		'roots',
		'remove',
		'warnings',
		'applied'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGGcPlanV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGGcPlanV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.gc-plan/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('operation' 'operation' true #(#literal #('gc'))).
		#('mode' 'mode' true #(#literal #('apply' 'dry-run'))).
		#('roots' 'roots' true #(#array #(#string))).
		#('remove' 'remove' true #(#array #(#model #KGJsonPathStorageRecord))).
		#('warnings' 'warnings' true #(#array #(#string))).
		#('applied' 'applied' true #(#boolean)) }
]

{ #category : 'json schema' }
KGGcPlanV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.gc-plan/1'
]

{ #category : 'accessing' }
KGGcPlanV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGGcPlanV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGGcPlanV1 >> operation [
	<return: #String>
	^ self defensiveJsonValue: operation
]

{ #category : 'accessing' }
KGGcPlanV1 >> mode [
	<return: #String>
	^ self defensiveJsonValue: mode
]

{ #category : 'accessing' }
KGGcPlanV1 >> roots [
	<return: #(Array<String>)>
	^ self defensiveJsonValue: roots
]

{ #category : 'accessing' }
KGGcPlanV1 >> remove [
	<return: #(Array<KGJsonPathStorageRecord>)>
	^ self defensiveJsonValue: remove
]

{ #category : 'accessing' }
KGGcPlanV1 >> warnings [
	<return: #(Array<String>)>
	^ self defensiveJsonValue: warnings
]

{ #category : 'accessing' }
KGGcPlanV1 >> applied [
	<return: #Boolean>
	^ self defensiveJsonValue: applied
]
