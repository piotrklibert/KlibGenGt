"
Construct class rename refactorings from the stable `class.rename` request.

- Slots
  - none
- Public API
  - {{gtMethod:KGClassRenameRefactoringAdapter>>#buildIn:request:}}
    Construct an `RBRenameClassRefactoring` in the supplied model.
"
Class {
	#name : 'KGClassRenameRefactoringAdapter',
	#superclass : 'KGRefactoringAdapter',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'building' }
KGClassRenameRefactoringAdapter >> buildIn: aModel request: aRequest [
	<arg: #aModel type: #GtRBNamespace>
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #RBRenameClassRefactoring>
	| arguments |
	arguments := self argumentsFrom: aRequest.
	^ RBRenameClassRefactoring
		model: aModel
		rename: (self require: 'class' in: arguments) asSymbol
		to: (self require: 'newName' in: arguments) asSymbol
]

{ #category : 'catalog' }
KGClassRenameRefactoringAdapter >> frameworkClassName [ <return: #String> ^ 'RBRenameClassRefactoring'
]

{ #category : 'catalog' }
KGClassRenameRefactoringAdapter >> identifier [ <return: #String> ^ 'class.rename'
]

{ #category : 'catalog' }
KGClassRenameRefactoringAdapter >> requiredArguments [ <return: #(Array<String>)> ^ #('class' 'newName')
]

{ #category : 'catalog' }
KGClassRenameRefactoringAdapter >> targetKind [ <return: #String> ^ 'class'
]
