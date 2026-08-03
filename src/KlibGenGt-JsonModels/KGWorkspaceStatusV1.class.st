"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `WorkspaceStatusV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `operation` (`#String`, `accessing`) - Value of JSON field `operation`.
  - `exists` (`#Boolean`, `accessing`) - Value of JSON field `exists`.
  - `name` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `name`.
  - `workspace` (`#(KGWorkspaceV1 | UndefinedObject)`, `accessing`) - Value of JSON field `workspace`.
  - `path` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `path`.
- Public API
  - {{gtMethod:KGWorkspaceStatusV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGWorkspaceStatusV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGWorkspaceStatusV1>>#operation}}
    Answer the immutable `operation` field value.
  - {{gtMethod:KGWorkspaceStatusV1>>#exists}}
    Answer the immutable `exists` field value.
  - {{gtMethod:KGWorkspaceStatusV1>>#name}}
    Answer the immutable `name` field value.
  - {{gtMethod:KGWorkspaceStatusV1>>#workspace}}
    Answer the immutable `workspace` field value.
  - {{gtMethod:KGWorkspaceStatusV1>>#path}}
    Answer the immutable `path` field value.
"
Class {
	#name : 'KGWorkspaceStatusV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'operation',
		'exists',
		'name',
		'workspace',
		'path'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGWorkspaceStatusV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGWorkspaceStatusV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.workspace-status/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('operation' 'operation' true #(#string)).
		#('exists' 'exists' true #(#boolean)).
		#('name' 'name' false #(#union #(#(#string) #(#nil)))).
		#('workspace' 'workspace' false #(#union #(#(#model #KGWorkspaceV1) #(#nil)))).
		#('path' 'path' false #(#union #(#(#string) #(#nil)))) }
]

{ #category : 'json schema' }
KGWorkspaceStatusV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.workspace-status/1'
]

{ #category : 'accessing' }
KGWorkspaceStatusV1 >> exists [
	<return: #Boolean>
	^ self defensiveJsonValue: exists
]

{ #category : 'accessing' }
KGWorkspaceStatusV1 >> name [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: name
]

{ #category : 'accessing' }
KGWorkspaceStatusV1 >> operation [
	<return: #String>
	^ self defensiveJsonValue: operation
]

{ #category : 'accessing' }
KGWorkspaceStatusV1 >> path [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: path
]

{ #category : 'accessing' }
KGWorkspaceStatusV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGWorkspaceStatusV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGWorkspaceStatusV1 >> workspace [
	<return: #(KGWorkspaceV1 | UndefinedObject)>
	^ self defensiveJsonValue: workspace
]
