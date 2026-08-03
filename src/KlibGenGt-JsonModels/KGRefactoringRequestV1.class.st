"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `RefactoringRequestV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `operation` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `operation`.
  - `refactoring` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `refactoring`.
  - `target` (`#((Dictionary<String, Any>) | UndefinedObject)`, `accessing`) - Value of JSON field `target`.
  - `arguments` (`#((Dictionary<String, Any>) | UndefinedObject)`, `accessing`) - Value of JSON field `arguments`.
  - `scope` (`#((Dictionary<String, Any>) | UndefinedObject)`, `accessing`) - Value of JSON field `scope`.
  - `limits` (`#((Dictionary<String, Any>) | UndefinedObject)`, `accessing`) - Value of JSON field `limits`.
  - `acknowledgedWarnings` (`#((Array<String>) | UndefinedObject)`, `accessing`) - Value of JSON field `acknowledgedWarnings`.
  - `allowPatternBlocks` (`#(Boolean | UndefinedObject)`, `accessing`) - Value of JSON field `allowPatternBlocks`.
  - `expect` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `expect`.
- Public API
  - {{gtMethod:KGRefactoringRequestV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGRefactoringRequestV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGRefactoringRequestV1>>#operation}}
    Answer the immutable `operation` field value.
  - {{gtMethod:KGRefactoringRequestV1>>#refactoring}}
    Answer the immutable `refactoring` field value.
  - {{gtMethod:KGRefactoringRequestV1>>#target}}
    Answer the immutable `target` field value.
  - {{gtMethod:KGRefactoringRequestV1>>#arguments}}
    Answer the immutable `arguments` field value.
  - {{gtMethod:KGRefactoringRequestV1>>#scope}}
    Answer the immutable `scope` field value.
  - {{gtMethod:KGRefactoringRequestV1>>#limits}}
    Answer the immutable `limits` field value.
  - {{gtMethod:KGRefactoringRequestV1>>#acknowledgedWarnings}}
    Answer the immutable `acknowledgedWarnings` field value.
  - {{gtMethod:KGRefactoringRequestV1>>#allowPatternBlocks}}
    Answer the immutable `allowPatternBlocks` field value.
  - {{gtMethod:KGRefactoringRequestV1>>#expect}}
    Answer the immutable `expect` field value.
"
Class {
	#name : 'KGRefactoringRequestV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'operation',
		'refactoring',
		'target',
		'arguments',
		'scope',
		'limits',
		'acknowledgedWarnings',
		'allowPatternBlocks',
		'expect'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGRefactoringRequestV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ true
]

{ #category : 'json schema' }
KGRefactoringRequestV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.refactoring-request/1'))).
		#('schemaVersion' 'schemaVersion' false #(#literal #(1))).
		#('operation' 'operation' false #(#union #(#(#string) #(#nil)))).
		#('refactoring' 'refactoring' false #(#union #(#(#string) #(#nil)))).
		#('target' 'target' false #(#union #(#(#dictionary #(#any)) #(#nil)))).
		#('arguments' 'arguments' false #(#union #(#(#dictionary #(#any)) #(#nil)))).
		#('scope' 'scope' false #(#union #(#(#dictionary #(#any)) #(#nil)))).
		#('limits' 'limits' false #(#union #(#(#dictionary #(#any)) #(#nil)))).
		#('acknowledgedWarnings' 'acknowledgedWarnings' false #(#union #(#(#array #(#string)) #(#nil)))).
		#('allowPatternBlocks' 'allowPatternBlocks' false #(#union #(#(#boolean) #(#nil)))).
		#('expect' 'expect' false #(#union #(#(#string) #(#nil)))) }
]

{ #category : 'json schema' }
KGRefactoringRequestV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.refactoring-request/1'
]

{ #category : 'accessing' }
KGRefactoringRequestV1 >> acknowledgedWarnings [
	<return: #((Array<String>) | UndefinedObject)>
	^ self defensiveJsonValue: acknowledgedWarnings
]

{ #category : 'accessing' }
KGRefactoringRequestV1 >> allowPatternBlocks [
	<return: #(Boolean | UndefinedObject)>
	^ self defensiveJsonValue: allowPatternBlocks
]

{ #category : 'accessing' }
KGRefactoringRequestV1 >> arguments [
	<return: #((Dictionary<String, Any>) | UndefinedObject)>
	^ self defensiveJsonValue: arguments
]

{ #category : 'accessing' }
KGRefactoringRequestV1 >> expect [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: expect
]

{ #category : 'accessing' }
KGRefactoringRequestV1 >> limits [
	<return: #((Dictionary<String, Any>) | UndefinedObject)>
	^ self defensiveJsonValue: limits
]

{ #category : 'accessing' }
KGRefactoringRequestV1 >> operation [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: operation
]

{ #category : 'accessing' }
KGRefactoringRequestV1 >> refactoring [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: refactoring
]

{ #category : 'accessing' }
KGRefactoringRequestV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGRefactoringRequestV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGRefactoringRequestV1 >> scope [
	<return: #((Dictionary<String, Any>) | UndefinedObject)>
	^ self defensiveJsonValue: scope
]

{ #category : 'accessing' }
KGRefactoringRequestV1 >> target [
	<return: #((Dictionary<String, Any>) | UndefinedObject)>
	^ self defensiveJsonValue: target
]
