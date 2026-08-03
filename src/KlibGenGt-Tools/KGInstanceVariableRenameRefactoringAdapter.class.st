"
Construct instance-variable rename refactorings for project classes.

- Slots
  - none
- Public API
  - {{gtMethod:KGInstanceVariableRenameRefactoringAdapter>>#buildIn:request:}}
    Construct an `RBRenameInstanceVariableRefactoring`.
"
Class {
	#name : 'KGInstanceVariableRenameRefactoringAdapter',
	#superclass : 'KGRefactoringAdapter',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'building' }
KGInstanceVariableRenameRefactoringAdapter >> buildIn: aModel request: aRequest [
	<arg: #aModel type: #GtRBNamespace>
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #RBRenameInstanceVariableRefactoring>
	| arguments |
	arguments := self argumentsFrom: aRequest.
	^ RBRenameInstanceVariableRefactoring
		model: aModel
		rename: (self require: 'oldName' in: arguments)
		to: (self require: 'newName' in: arguments)
		in: (self classNamed: (self require: 'class' in: arguments) in: aModel)
]

{ #category : 'catalog' }
KGInstanceVariableRenameRefactoringAdapter >> frameworkClassName [ <return: #String> ^ 'RBRenameInstanceVariableRefactoring'
]

{ #category : 'catalog' }
KGInstanceVariableRenameRefactoringAdapter >> identifier [ <return: #String> ^ 'instance-variable.rename'
]

{ #category : 'catalog' }
KGInstanceVariableRenameRefactoringAdapter >> requiredArguments [ <return: #(Array<String>)> ^ #('class' 'oldName' 'newName')
]

{ #category : 'catalog' }
KGInstanceVariableRenameRefactoringAdapter >> targetKind [ <return: #String> ^ 'variable'
]
