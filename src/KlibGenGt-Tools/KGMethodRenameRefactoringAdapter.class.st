"
Construct method rename refactorings with an explicit argument permutation.

- Slots
  - none
- Public API
  - {{gtMethod:KGMethodRenameRefactoringAdapter>>#buildIn:request:}}
    Construct an `RBRenameMethodRefactoring` for one method side.
"
Class {
	#name : 'KGMethodRenameRefactoringAdapter',
	#superclass : 'KGRefactoringAdapter',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'building' }
KGMethodRenameRefactoringAdapter >> buildIn: aModel request: aRequest [
	<arg: #aModel type: #GtRBNamespace>
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #RBRenameMethodRefactoring>
	| arguments selector newSelector permutation |
	arguments := self argumentsFrom: aRequest.
	selector := (self require: 'selector' in: arguments) asSymbol.
	newSelector := (self require: 'newSelector' in: arguments) asSymbol.
	permutation := arguments
		at: 'argumentPermutation'
		ifAbsent: [ (1 to: selector numArgs) asArray ].
	^ RBRenameMethodRefactoring
		model: aModel
		renameMethod: selector
		in: (self methodClassFrom: arguments in: aModel)
		to: newSelector
		permutation: permutation
]

{ #category : 'catalog' }
KGMethodRenameRefactoringAdapter >> frameworkClassName [ <return: #String> ^ 'RBRenameMethodRefactoring'
]

{ #category : 'catalog' }
KGMethodRenameRefactoringAdapter >> identifier [ <return: #String> ^ 'method.rename'
]

{ #category : 'catalog' }
KGMethodRenameRefactoringAdapter >> optionalArguments [ <return: #(Array<String>)> ^ #('side' 'argumentPermutation')
]

{ #category : 'catalog' }
KGMethodRenameRefactoringAdapter >> requiredArguments [ <return: #(Array<String>)> ^ #('class' 'selector' 'newSelector')
]

{ #category : 'catalog' }
KGMethodRenameRefactoringAdapter >> targetKind [ <return: #String> ^ 'method'
]
