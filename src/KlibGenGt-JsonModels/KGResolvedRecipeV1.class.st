"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `ResolvedRecipeV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `operation` (`#String`, `accessing`) - Value of JSON field `operation`.
  - `target` (`#String`, `accessing`) - Value of JSON field `target`.
  - `recipe` (`#String`, `accessing`) - Value of JSON field `recipe`.
  - `preset` (`#KGJsonLaunchPresetRecord`, `accessing`) - Value of JSON field `preset`.
  - `steps` (`#(Array<KGJsonResolvedStepRecord>)`, `accessing`) - Value of JSON field `steps`.
  - `outputKey` (`#String`, `accessing`) - Value of JSON field `outputKey`.
- Public API
  - {{gtMethod:KGResolvedRecipeV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGResolvedRecipeV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGResolvedRecipeV1>>#operation}}
    Answer the immutable `operation` field value.
  - {{gtMethod:KGResolvedRecipeV1>>#target}}
    Answer the immutable `target` field value.
  - {{gtMethod:KGResolvedRecipeV1>>#recipe}}
    Answer the immutable `recipe` field value.
  - {{gtMethod:KGResolvedRecipeV1>>#preset}}
    Answer the immutable `preset` field value.
  - {{gtMethod:KGResolvedRecipeV1>>#steps}}
    Answer the immutable `steps` field value.
  - {{gtMethod:KGResolvedRecipeV1>>#outputKey}}
    Answer the immutable `outputKey` field value.
"
Class {
	#name : 'KGResolvedRecipeV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'operation',
		'target',
		'recipe',
		'preset',
		'steps',
		'outputKey'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGResolvedRecipeV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ true
]

{ #category : 'json schema' }
KGResolvedRecipeV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.resolved-recipe/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('operation' 'operation' true #(#string)).
		#('target' 'target' true #(#string)).
		#('recipe' 'recipe' true #(#string)).
		#('preset' 'preset' true #(#model #KGJsonLaunchPresetRecord)).
		#('steps' 'steps' true #(#array #(#model #KGJsonResolvedStepRecord))).
		#('outputKey' 'outputKey' true #(#string)) }
]

{ #category : 'json schema' }
KGResolvedRecipeV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.resolved-recipe/1'
]

{ #category : 'accessing' }
KGResolvedRecipeV1 >> operation [
	<return: #String>
	^ self defensiveJsonValue: operation
]

{ #category : 'accessing' }
KGResolvedRecipeV1 >> outputKey [
	<return: #String>
	^ self defensiveJsonValue: outputKey
]

{ #category : 'accessing' }
KGResolvedRecipeV1 >> preset [
	<return: #KGJsonLaunchPresetRecord>
	^ self defensiveJsonValue: preset
]

{ #category : 'accessing' }
KGResolvedRecipeV1 >> recipe [
	<return: #String>
	^ self defensiveJsonValue: recipe
]

{ #category : 'accessing' }
KGResolvedRecipeV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGResolvedRecipeV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGResolvedRecipeV1 >> steps [
	<return: #(Array<KGJsonResolvedStepRecord>)>
	^ self defensiveJsonValue: steps
]

{ #category : 'accessing' }
KGResolvedRecipeV1 >> target [
	<return: #String>
	^ self defensiveJsonValue: target
]
