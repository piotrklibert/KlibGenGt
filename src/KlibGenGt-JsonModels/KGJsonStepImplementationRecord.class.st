"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `StepImplementationRecord`.

- Slots
  - `identifier` (`#String`, `accessing`) - Value of JSON field `identifier`.
  - `version` (`#Integer`, `accessing`) - Value of JSON field `version`.
  - `inputType` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `inputType`.
  - `outputType` (`#String`, `accessing`) - Value of JSON field `outputType`.
  - `inputs` (`#(Array<String>)`, `accessing`) - Value of JSON field `inputs`.
- Public API
  - {{gtMethod:KGJsonStepImplementationRecord>>#identifier}}
    Answer the immutable `identifier` field value.
  - {{gtMethod:KGJsonStepImplementationRecord>>#version}}
    Answer the immutable `version` field value.
  - {{gtMethod:KGJsonStepImplementationRecord>>#inputType}}
    Answer the immutable `inputType` field value.
  - {{gtMethod:KGJsonStepImplementationRecord>>#outputType}}
    Answer the immutable `outputType` field value.
  - {{gtMethod:KGJsonStepImplementationRecord>>#inputs}}
    Answer the immutable `inputs` field value."
Class {
	#name : 'KGJsonStepImplementationRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'identifier',
		'version',
		'inputType',
		'outputType',
		'inputs'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonStepImplementationRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonStepImplementationRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('identifier' 'identifier' true #(#string)).
		#('version' 'version' true #(#constrained #(#integer) #(#(#ge 1)))).
		#('inputType' 'inputType' true #(#union #(#(#string) #(#nil)))).
		#('outputType' 'outputType' true #(#string)).
		#('inputs' 'inputs' true #(#array #(#string))) }
]

{ #category : 'json schema' }
KGJsonStepImplementationRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonStepImplementationRecord >> identifier [
	<return: #String>
	^ self defensiveJsonValue: identifier
]

{ #category : 'accessing' }
KGJsonStepImplementationRecord >> version [
	<return: #Integer>
	^ self defensiveJsonValue: version
]

{ #category : 'accessing' }
KGJsonStepImplementationRecord >> inputType [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: inputType
]

{ #category : 'accessing' }
KGJsonStepImplementationRecord >> outputType [
	<return: #String>
	^ self defensiveJsonValue: outputType
]

{ #category : 'accessing' }
KGJsonStepImplementationRecord >> inputs [
	<return: #(Array<String>)>
	^ self defensiveJsonValue: inputs
]
