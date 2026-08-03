"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `ArtifactV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `artifactType` (`#String`, `accessing`) - Value of JSON field `artifactType`.
  - `outputKey` (`#String`, `accessing`) - Value of JSON field `outputKey`.
  - `producingRole` (`#String`, `accessing`) - Value of JSON field `producingRole`.
  - `payloadShapeDigest` (`#String`, `accessing`) - Value of JSON field `payloadShapeDigest`.
  - `platform` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `platform`.
  - `resolvedRecipe` (`#(KGResolvedRecipeV1 | (Dictionary<String, Any>) | UndefinedObject)`, `accessing`) - Value of JSON field `resolvedRecipe`.
  - `path` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `path`.
  - `valid` (`#(Boolean | UndefinedObject)`, `accessing`) - Value of JSON field `valid`.
  - `storage` (`#(KGJsonStorageRecord | UndefinedObject)`, `accessing`) - Value of JSON field `storage`.
- Public API
  - {{gtMethod:KGArtifactV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGArtifactV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGArtifactV1>>#artifactType}}
    Answer the immutable `artifactType` field value.
  - {{gtMethod:KGArtifactV1>>#outputKey}}
    Answer the immutable `outputKey` field value.
  - {{gtMethod:KGArtifactV1>>#producingRole}}
    Answer the immutable `producingRole` field value.
  - {{gtMethod:KGArtifactV1>>#payloadShapeDigest}}
    Answer the immutable `payloadShapeDigest` field value.
  - {{gtMethod:KGArtifactV1>>#platform}}
    Answer the immutable `platform` field value.
  - {{gtMethod:KGArtifactV1>>#resolvedRecipe}}
    Answer the immutable `resolvedRecipe` field value.
  - {{gtMethod:KGArtifactV1>>#path}}
    Answer the immutable `path` field value.
  - {{gtMethod:KGArtifactV1>>#valid}}
    Answer the immutable `valid` field value.
  - {{gtMethod:KGArtifactV1>>#storage}}
    Answer the immutable `storage` field value.
"
Class {
	#name : 'KGArtifactV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'artifactType',
		'outputKey',
		'producingRole',
		'payloadShapeDigest',
		'platform',
		'resolvedRecipe',
		'path',
		'valid',
		'storage'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGArtifactV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ true
]

{ #category : 'json schema' }
KGArtifactV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.artifact/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('artifactType' 'artifactType' true #(#string)).
		#('outputKey' 'outputKey' true #(#string)).
		#('producingRole' 'producingRole' true #(#string)).
		#('payloadShapeDigest' 'payloadShapeDigest' true #(#string)).
		#('platform' 'platform' false #(#union #(#(#string) #(#nil)))).
		#('resolvedRecipe' 'resolvedRecipe' false #(#union #(#(#model #KGResolvedRecipeV1) #(#dictionary #(#any)) #(#nil)))).
		#('path' 'path' false #(#union #(#(#string) #(#nil)))).
		#('valid' 'valid' false #(#union #(#(#boolean) #(#nil)))).
		#('storage' 'storage' false #(#union #(#(#model #KGJsonStorageRecord) #(#nil)))) }
]

{ #category : 'json schema' }
KGArtifactV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.artifact/1'
]

{ #category : 'accessing' }
KGArtifactV1 >> artifactType [
	<return: #String>
	^ self defensiveJsonValue: artifactType
]

{ #category : 'accessing' }
KGArtifactV1 >> outputKey [
	<return: #String>
	^ self defensiveJsonValue: outputKey
]

{ #category : 'accessing' }
KGArtifactV1 >> path [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: path
]

{ #category : 'accessing' }
KGArtifactV1 >> payloadShapeDigest [
	<return: #String>
	^ self defensiveJsonValue: payloadShapeDigest
]

{ #category : 'accessing' }
KGArtifactV1 >> platform [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: platform
]

{ #category : 'accessing' }
KGArtifactV1 >> producingRole [
	<return: #String>
	^ self defensiveJsonValue: producingRole
]

{ #category : 'accessing' }
KGArtifactV1 >> resolvedRecipe [
	<return: #(KGResolvedRecipeV1 | (Dictionary<String, Any>) | UndefinedObject)>
	^ self defensiveJsonValue: resolvedRecipe
]

{ #category : 'accessing' }
KGArtifactV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGArtifactV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGArtifactV1 >> storage [
	<return: #(KGJsonStorageRecord | UndefinedObject)>
	^ self defensiveJsonValue: storage
]

{ #category : 'accessing' }
KGArtifactV1 >> valid [
	<return: #(Boolean | UndefinedObject)>
	^ self defensiveJsonValue: valid
]
