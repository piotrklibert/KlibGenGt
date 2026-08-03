"
Construct parameter-removal refactorings identified by argument name.

- Slots
  - none
- Public API
  - {{gtMethod:KGParameterRemoveRefactoringAdapter>>#buildIn:request:}}
    Construct an `RBRemoveParameterRefactoring` for one method.
"
Class {
	#name : 'KGParameterRemoveRefactoringAdapter',
	#superclass : 'KGRefactoringAdapter',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'building' }
KGParameterRemoveRefactoringAdapter >> buildIn: aModel request: aRequest [
	<arg: #aModel type: #GtRBNamespace>
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #RBRemoveParameterRefactoring>
	| arguments |
	arguments := self argumentsFrom: aRequest.
	^ RBRemoveParameterRefactoring
		model: aModel
		removeParameter: (self require: 'name' in: arguments)
		in: (self methodClassFrom: arguments in: aModel)
		selector: (self require: 'selector' in: arguments) asSymbol
]

{ #category : 'catalog' }
KGParameterRemoveRefactoringAdapter >> frameworkClassName [ <return: #String> ^ 'RBRemoveParameterRefactoring'
]

{ #category : 'catalog' }
KGParameterRemoveRefactoringAdapter >> identifier [ <return: #String> ^ 'parameter.remove'
]

{ #category : 'catalog' }
KGParameterRemoveRefactoringAdapter >> optionalArguments [ <return: #(Array<String>)> ^ #('side')
]

{ #category : 'catalog' }
KGParameterRemoveRefactoringAdapter >> requiredArguments [ <return: #(Array<String>)> ^ #('class' 'selector' 'name')
]

{ #category : 'catalog' }
KGParameterRemoveRefactoringAdapter >> targetKind [ <return: #String> ^ 'parameter'
]
