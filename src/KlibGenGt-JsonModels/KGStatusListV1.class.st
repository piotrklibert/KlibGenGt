"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `StatusListV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `operation` (`#String`, `accessing`) - Value of JSON field `operation`.
  - `statuses` (`#(Array<KGBuildStatusV1>)`, `accessing`) - Value of JSON field `statuses`.
  - `workspace` (`#KGWorkspaceStatusV1`, `accessing`) - Value of JSON field `workspace`.
- Public API
  - {{gtMethod:KGStatusListV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGStatusListV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGStatusListV1>>#operation}}
    Answer the immutable `operation` field value.
  - {{gtMethod:KGStatusListV1>>#statuses}}
    Answer the immutable `statuses` field value.
  - {{gtMethod:KGStatusListV1>>#workspace}}
    Answer the immutable `workspace` field value.
"
Class {
	#name : 'KGStatusListV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'operation',
		'statuses',
		'workspace'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGStatusListV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGStatusListV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.status-list/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('operation' 'operation' true #(#literal #('status'))).
		#('statuses' 'statuses' true #(#array #(#model #KGBuildStatusV1))).
		#('workspace' 'workspace' true #(#model #KGWorkspaceStatusV1)) }
]

{ #category : 'json schema' }
KGStatusListV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.status-list/1'
]

{ #category : 'accessing' }
KGStatusListV1 >> operation [
	<return: #String>
	^ self defensiveJsonValue: operation
]

{ #category : 'accessing' }
KGStatusListV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGStatusListV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGStatusListV1 >> statuses [
	<return: #(Array<KGBuildStatusV1>)>
	^ self defensiveJsonValue: statuses
]

{ #category : 'accessing' }
KGStatusListV1 >> workspace [
	<return: #KGWorkspaceStatusV1>
	^ self defensiveJsonValue: workspace
]
