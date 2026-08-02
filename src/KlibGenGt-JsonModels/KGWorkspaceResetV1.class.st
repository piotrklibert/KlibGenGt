"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `WorkspaceResetV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `operation` (`#String`, `accessing`) - Value of JSON field `operation`.
  - `name` (`#String`, `accessing`) - Value of JSON field `name`.
  - `removed` (`#Boolean`, `accessing`) - Value of JSON field `removed`.
- Public API
  - {{gtMethod:KGWorkspaceResetV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGWorkspaceResetV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGWorkspaceResetV1>>#operation}}
    Answer the immutable `operation` field value.
  - {{gtMethod:KGWorkspaceResetV1>>#name}}
    Answer the immutable `name` field value.
  - {{gtMethod:KGWorkspaceResetV1>>#removed}}
    Answer the immutable `removed` field value."
Class {
	#name : 'KGWorkspaceResetV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'operation',
		'name',
		'removed'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGWorkspaceResetV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGWorkspaceResetV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.workspace-reset/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('operation' 'operation' true #(#string)).
		#('name' 'name' true #(#string)).
		#('removed' 'removed' true #(#boolean)) }
]

{ #category : 'json schema' }
KGWorkspaceResetV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.workspace-reset/1'
]

{ #category : 'accessing' }
KGWorkspaceResetV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGWorkspaceResetV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGWorkspaceResetV1 >> operation [
	<return: #String>
	^ self defensiveJsonValue: operation
]

{ #category : 'accessing' }
KGWorkspaceResetV1 >> name [
	<return: #String>
	^ self defensiveJsonValue: name
]

{ #category : 'accessing' }
KGWorkspaceResetV1 >> removed [
	<return: #Boolean>
	^ self defensiveJsonValue: removed
]
