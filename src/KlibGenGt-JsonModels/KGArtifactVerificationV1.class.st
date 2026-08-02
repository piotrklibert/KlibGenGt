"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `ArtifactVerificationV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `operation` (`#String`, `accessing`) - Value of JSON field `operation`.
  - `path` (`#String`, `accessing`) - Value of JSON field `path`.
  - `manifest` (`#KGArtifactV1`, `accessing`) - Value of JSON field `manifest`.
  - `valid` (`#Boolean`, `accessing`) - Value of JSON field `valid`.
- Public API
  - {{gtMethod:KGArtifactVerificationV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGArtifactVerificationV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGArtifactVerificationV1>>#operation}}
    Answer the immutable `operation` field value.
  - {{gtMethod:KGArtifactVerificationV1>>#path}}
    Answer the immutable `path` field value.
  - {{gtMethod:KGArtifactVerificationV1>>#manifest}}
    Answer the immutable `manifest` field value.
  - {{gtMethod:KGArtifactVerificationV1>>#valid}}
    Answer the immutable `valid` field value."
Class {
	#name : 'KGArtifactVerificationV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'operation',
		'path',
		'manifest',
		'valid'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGArtifactVerificationV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGArtifactVerificationV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.artifact-verification/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('operation' 'operation' true #(#string)).
		#('path' 'path' true #(#string)).
		#('manifest' 'manifest' true #(#model #KGArtifactV1)).
		#('valid' 'valid' true #(#literal #(true))) }
]

{ #category : 'json schema' }
KGArtifactVerificationV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.artifact-verification/1'
]

{ #category : 'accessing' }
KGArtifactVerificationV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGArtifactVerificationV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGArtifactVerificationV1 >> operation [
	<return: #String>
	^ self defensiveJsonValue: operation
]

{ #category : 'accessing' }
KGArtifactVerificationV1 >> path [
	<return: #String>
	^ self defensiveJsonValue: path
]

{ #category : 'accessing' }
KGArtifactVerificationV1 >> manifest [
	<return: #KGArtifactV1>
	^ self defensiveJsonValue: manifest
]

{ #category : 'accessing' }
KGArtifactVerificationV1 >> valid [
	<return: #Boolean>
	^ self defensiveJsonValue: valid
]
