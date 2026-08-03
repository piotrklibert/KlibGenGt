"
Construct parameter-add refactorings while deriving the framework permutation.

- Slots
  - none
- Public API
  - {{gtMethod:KGParameterAddRefactoringAdapter>>#buildIn:request:}}
    Construct an `RBAddParameterRefactoring` for one method.
"
Class {
	#name : 'KGParameterAddRefactoringAdapter',
	#superclass : 'KGRefactoringAdapter',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'building' }
KGParameterAddRefactoringAdapter >> buildIn: aModel request: aRequest [
	<arg: #aModel type: #GtRBNamespace>
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #RBAddParameterRefactoring>
	| arguments selector newSelector insertion permutation newArgument |
	arguments := self argumentsFrom: aRequest.
	selector := (self require: 'selector' in: arguments) asSymbol.
	newSelector := (self require: 'newSelector' in: arguments) asSymbol.
	insertion := self require: 'insertionIndex' in: arguments.
	newSelector numArgs = selector numArgs + 1 ifFalse: [ self error: 'new selector must add exactly one argument' ].
	(insertion isInteger and: [ insertion between: 1 and: newSelector numArgs ]) ifFalse: [
		self error: 'insertionIndex is outside the new selector' ].
	permutation := (1 to: newSelector numArgs) collect: [ :index |
		index = insertion ifTrue: [ -1 ] ifFalse: [ index < insertion ifTrue: [ index ] ifFalse: [ index - 1 ] ] ].
	newArgument := RBArgumentName
		name: (self require: 'name' in: arguments)
		value: (self require: 'defaultExpression' in: arguments).
	^ RBAddParameterRefactoring
		model: aModel
		addParameterToMethod: selector
		in: (self methodClassFrom: arguments in: aModel)
		newSelector: newSelector
		permutation: permutation asArray
		newArgs: { newArgument }
]

{ #category : 'catalog' }
KGParameterAddRefactoringAdapter >> frameworkClassName [ <return: #String> ^ 'RBAddParameterRefactoring'
]

{ #category : 'catalog' }
KGParameterAddRefactoringAdapter >> identifier [ <return: #String> ^ 'parameter.add'
]

{ #category : 'catalog' }
KGParameterAddRefactoringAdapter >> optionalArguments [ <return: #(Array<String>)> ^ #('side')
]

{ #category : 'catalog' }
KGParameterAddRefactoringAdapter >> requiredArguments [ <return: #(Array<String>)> ^ #('class' 'selector' 'newSelector' 'insertionIndex' 'name' 'defaultExpression')
]

{ #category : 'catalog' }
KGParameterAddRefactoringAdapter >> targetKind [ <return: #String> ^ 'parameter'
]
