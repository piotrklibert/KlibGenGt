"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `ArtifactListV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `operation` (`#String`, `accessing`) - Value of JSON field `operation`.
  - `artifacts` (`#(Array<(KGArtifactV1 | KGJsonInvalidArtifactRecord)>)`, `accessing`) - Value of JSON field `artifacts`.
- Public API
  - {{gtMethod:KGArtifactListV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGArtifactListV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGArtifactListV1>>#operation}}
    Answer the immutable `operation` field value.
  - {{gtMethod:KGArtifactListV1>>#artifacts}}
    Answer the immutable `artifacts` field value.
"
Class {
	#name : 'KGArtifactListV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'operation',
		'artifacts'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGArtifactListV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGArtifactListV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.artifact-list/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('operation' 'operation' true #(#string)).
		#('artifacts' 'artifacts' true #(#array #(#union #(#(#model #KGArtifactV1) #(#model #KGJsonInvalidArtifactRecord))))) }
]

{ #category : 'json schema' }
KGArtifactListV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.artifact-list/1'
]

{ #category : 'accessing' }
KGArtifactListV1 >> artifacts [
	<return: #(Array<(KGArtifactV1 | KGJsonInvalidArtifactRecord)>)>
	^ self defensiveJsonValue: artifacts
]

{ #category : 'accessing' }
KGArtifactListV1 >> operation [
	<return: #String>
	^ self defensiveJsonValue: operation
]

{ #category : 'accessing' }
KGArtifactListV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGArtifactListV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]
