"
Construct method moves through a named variable and an explicit inferred target class.

- Slots
  - none
- Public API
  - {{gtMethod:KGMethodMoveRefactoringAdapter>>#buildIn:request:}}
    Construct and configure a `GtMoveMethodRefactoring`.
"
Class {
	#name : 'KGMethodMoveRefactoringAdapter',
	#superclass : 'KGRefactoringAdapter',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'building' }
KGMethodMoveRefactoringAdapter >> buildIn: aModel request: aRequest [
	<arg: #aModel type: #GtRBNamespace>
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #GtMoveMethodRefactoring>
	| arguments refactoring target selfName sourceName |
	arguments := self argumentsFrom: aRequest.
	target := self classNamed: (self require: 'targetClass' in: arguments) in: aModel.
	refactoring := GtMoveMethodRefactoring
		model: aModel
		selector: (self require: 'selector' in: arguments) asSymbol
		class: (self methodClassFrom: arguments in: aModel)
		variable: (self require: 'viaVariable' in: arguments).
	refactoring setOption: #variableTypes toUse: [ :ref :types :selected | { target } ].
	sourceName := self require: 'class' in: arguments.
	selfName := arguments at: 'selfArgumentName' ifAbsent: [
		((sourceName first isVowel ifTrue: [ 'an' ] ifFalse: [ 'a' ]), sourceName) ].
	refactoring setOption: #selfArgumentName toUse: [ :ref | selfName ].
	^ refactoring
]

{ #category : 'catalog' }
KGMethodMoveRefactoringAdapter >> frameworkClassName [ <return: #String> ^ 'GtMoveMethodRefactoring'
]

{ #category : 'catalog' }
KGMethodMoveRefactoringAdapter >> identifier [ <return: #String> ^ 'method.move'
]

{ #category : 'catalog' }
KGMethodMoveRefactoringAdapter >> optionalArguments [ <return: #(Array<String>)> ^ #('side' 'selfArgumentName')
]

{ #category : 'catalog' }
KGMethodMoveRefactoringAdapter >> requiredArguments [ <return: #(Array<String>)> ^ #('class' 'selector' 'viaVariable' 'targetClass')
]

{ #category : 'catalog' }
KGMethodMoveRefactoringAdapter >> targetKind [ <return: #String> ^ 'method'
]
