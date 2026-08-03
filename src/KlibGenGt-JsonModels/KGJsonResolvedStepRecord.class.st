"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `ResolvedStepRecord`.

- Slots
  - `role` (`#String`, `accessing`) - Value of JSON field `role`.
  - `implementation` (`#KGJsonStepImplementationRecord`, `accessing`) - Value of JSON field `implementation`.
  - `implementationInputs` (`#KGJsonPathDigestRecord`, `accessing`) - Value of JSON field `implementationInputs`.
  - `resolvedConfiguration` (`#(Dictionary<String, Any>)`, `accessing`) - Value of JSON field `resolvedConfiguration`.
  - `parentOutputKey` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `parentOutputKey`.
  - `stepKey` (`#String`, `accessing`) - Value of JSON field `stepKey`.
  - `outputKey` (`#String`, `accessing`) - Value of JSON field `outputKey`.
  - `checkpoint` (`#String`, `accessing`) - Value of JSON field `checkpoint`.
  - `origin` (`#String`, `accessing`) - Value of JSON field `origin`.
- Public API
  - {{gtMethod:KGJsonResolvedStepRecord>>#role}}
    Answer the immutable `role` field value.
  - {{gtMethod:KGJsonResolvedStepRecord>>#implementation}}
    Answer the immutable `implementation` field value.
  - {{gtMethod:KGJsonResolvedStepRecord>>#implementationInputs}}
    Answer the immutable `implementationInputs` field value.
  - {{gtMethod:KGJsonResolvedStepRecord>>#resolvedConfiguration}}
    Answer the immutable `resolvedConfiguration` field value.
  - {{gtMethod:KGJsonResolvedStepRecord>>#parentOutputKey}}
    Answer the immutable `parentOutputKey` field value.
  - {{gtMethod:KGJsonResolvedStepRecord>>#stepKey}}
    Answer the immutable `stepKey` field value.
  - {{gtMethod:KGJsonResolvedStepRecord>>#outputKey}}
    Answer the immutable `outputKey` field value.
  - {{gtMethod:KGJsonResolvedStepRecord>>#checkpoint}}
    Answer the immutable `checkpoint` field value.
  - {{gtMethod:KGJsonResolvedStepRecord>>#origin}}
    Answer the immutable `origin` field value.
"
Class {
	#name : 'KGJsonResolvedStepRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'role',
		'implementation',
		'implementationInputs',
		'resolvedConfiguration',
		'parentOutputKey',
		'stepKey',
		'outputKey',
		'checkpoint',
		'origin'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonResolvedStepRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ true
]

{ #category : 'json schema' }
KGJsonResolvedStepRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('role' 'role' true #(#string)).
		#('implementation' 'implementation' true #(#model #KGJsonStepImplementationRecord)).
		#('implementationInputs' 'implementationInputs' true #(#model #KGJsonPathDigestRecord)).
		#('resolvedConfiguration' 'resolvedConfiguration' true #(#dictionary #(#any))).
		#('parentOutputKey' 'parentOutputKey' true #(#union #(#(#string) #(#nil)))).
		#('stepKey' 'stepKey' true #(#string)).
		#('outputKey' 'outputKey' true #(#string)).
		#('checkpoint' 'checkpoint' true #(#literal #('none' 'artifact'))).
		#('origin' 'origin' true #(#string)) }
]

{ #category : 'json schema' }
KGJsonResolvedStepRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonResolvedStepRecord >> checkpoint [
	<return: #String>
	^ self defensiveJsonValue: checkpoint
]

{ #category : 'accessing' }
KGJsonResolvedStepRecord >> implementation [
	<return: #KGJsonStepImplementationRecord>
	^ self defensiveJsonValue: implementation
]

{ #category : 'accessing' }
KGJsonResolvedStepRecord >> implementationInputs [
	<return: #KGJsonPathDigestRecord>
	^ self defensiveJsonValue: implementationInputs
]

{ #category : 'accessing' }
KGJsonResolvedStepRecord >> origin [
	<return: #String>
	^ self defensiveJsonValue: origin
]

{ #category : 'accessing' }
KGJsonResolvedStepRecord >> outputKey [
	<return: #String>
	^ self defensiveJsonValue: outputKey
]

{ #category : 'accessing' }
KGJsonResolvedStepRecord >> parentOutputKey [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: parentOutputKey
]

{ #category : 'accessing' }
KGJsonResolvedStepRecord >> resolvedConfiguration [
	<return: #(Dictionary<String, Any>)>
	^ self defensiveJsonValue: resolvedConfiguration
]

{ #category : 'accessing' }
KGJsonResolvedStepRecord >> role [
	<return: #String>
	^ self defensiveJsonValue: role
]

{ #category : 'accessing' }
KGJsonResolvedStepRecord >> stepKey [
	<return: #String>
	^ self defensiveJsonValue: stepKey
]
