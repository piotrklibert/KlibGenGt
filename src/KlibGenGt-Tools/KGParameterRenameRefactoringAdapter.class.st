"
Construct argument rename refactorings by resolving the argument AST interval.

- Slots
  - none
- Public API
  - {{gtMethod:KGParameterRenameRefactoringAdapter>>#buildIn:request:}}
    Construct an `RBRenameArgumentOrTemporaryRefactoring` for a named argument.
"
Class {
	#name : 'KGParameterRenameRefactoringAdapter',
	#superclass : 'KGRefactoringAdapter',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'building' }
KGParameterRenameRefactoringAdapter >> buildIn: aModel request: aRequest [
	<arg: #aModel type: #GtRBNamespace>
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #RBRenameArgumentOrTemporaryRefactoring>
	| arguments modelClass selector node |
	arguments := self argumentsFrom: aRequest.
	modelClass := self methodClassFrom: arguments in: aModel.
	selector := (self require: 'selector' in: arguments) asSymbol.
	node := (modelClass parseTreeForSelector: selector) arguments
		detect: [ :argument | argument name = (self require: 'oldName' in: arguments) ]
		ifNone: [ self error: 'method argument not found' ].
	^ RBRenameArgumentOrTemporaryRefactoring
		model: aModel
		renameTemporaryFrom: node sourceInterval
		to: (self require: 'newName' in: arguments)
		in: modelClass
		selector: selector
]

{ #category : 'catalog' }
KGParameterRenameRefactoringAdapter >> frameworkClassName [ <return: #String> ^ 'RBRenameArgumentOrTemporaryRefactoring'
]

{ #category : 'catalog' }
KGParameterRenameRefactoringAdapter >> identifier [ <return: #String> ^ 'parameter.rename'
]

{ #category : 'catalog' }
KGParameterRenameRefactoringAdapter >> optionalArguments [ <return: #(Array<String>)> ^ #('side')
]

{ #category : 'catalog' }
KGParameterRenameRefactoringAdapter >> requiredArguments [ <return: #(Array<String>)> ^ #('class' 'selector' 'oldName' 'newName')
]

{ #category : 'catalog' }
KGParameterRenameRefactoringAdapter >> targetKind [ <return: #String> ^ 'parameter'
]
