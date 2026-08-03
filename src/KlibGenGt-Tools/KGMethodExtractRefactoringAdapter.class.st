"
Construct method extraction refactorings from exact selected source text.

- Slots
  - none
- Public API
  - {{gtMethod:KGMethodExtractRefactoringAdapter>>#buildIn:request:}}
    Validate the method hash, derive the selection interval, and configure extraction.
"
Class {
	#name : 'KGMethodExtractRefactoringAdapter',
	#superclass : 'KGRefactoringAdapter',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'private - source' }
KGMethodExtractRefactoringAdapter >> behaviorFrom: arguments [
	<arg: #arguments type: #(Dictionary<String, Any>)>
	<return: #Behavior>
	| behavior side |
	behavior := Smalltalk globals
		at: (self require: 'class' in: arguments) asSymbol
		ifAbsent: [ self error: 'unknown class: ', (arguments at: 'class') ].
	(behavior package name beginsWith: 'KlibGenGt-') ifFalse: [
		self error: 'refactoring targets are limited to KlibGenGt packages' ].
	side := arguments at: 'side' ifAbsent: [ 'instance' ].
	(#('instance' 'class') includes: side) ifFalse: [ self error: 'side must be instance or class' ].
	^ side = 'class' ifTrue: [ behavior class ] ifFalse: [ behavior ]
]

{ #category : 'building' }
KGMethodExtractRefactoringAdapter >> buildIn: aModel request: aRequest [
	<arg: #aModel type: #GtRBNamespace>
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #RBExtractMethodRefactoring>
	| arguments selector behavior source expected selected occurrence start cursor refactoring newSelector |
	arguments := self argumentsFrom: aRequest.
	selector := (self require: 'selector' in: arguments) asSymbol.
	behavior := self behaviorFrom: arguments.
	source := (behavior compiledMethodAt: selector ifAbsent: [ self error: 'method not found' ]) sourceCode.
	expected := self require: 'expectedMethodHash' in: arguments.
	(self sha256: source) = expected ifFalse: [ self error: 'method source hash changed; retrieve the method again' ].
	selected := self require: 'selectedSource' in: arguments.
	occurrence := arguments at: 'occurrence' ifAbsent: [ 1 ].
	occurrence isInteger ifFalse: [ self error: 'occurrence must be an integer' ].
	occurrence > 0 ifFalse: [ self error: 'occurrence must be positive' ].
	cursor := 1.
	1 to: occurrence do: [ :index |
		start := source findString: selected startingAt: cursor.
		start = 0 ifTrue: [ self error: 'selected source occurrence was not found' ].
		cursor := start + selected size ].
	refactoring := RBExtractMethodRefactoring
		model: aModel
		extract: (start to: start + selected size - 1)
		from: selector
		in: (self methodClassFrom: arguments in: aModel).
	newSelector := (self require: 'newSelector' in: arguments) asSymbol.
	refactoring setOption: #methodName toUse: [ :methodName :ref |
		methodName selector: newSelector; yourself ].
	^ refactoring
]

{ #category : 'catalog' }
KGMethodExtractRefactoringAdapter >> frameworkClassName [ <return: #String> ^ 'RBExtractMethodRefactoring'
]

{ #category : 'catalog' }
KGMethodExtractRefactoringAdapter >> identifier [ <return: #String> ^ 'method.extract'
]

{ #category : 'catalog' }
KGMethodExtractRefactoringAdapter >> optionalArguments [ <return: #(Array<String>)> ^ #('side' 'occurrence')
]

{ #category : 'catalog' }
KGMethodExtractRefactoringAdapter >> requiredArguments [ <return: #(Array<String>)> ^ #('class' 'selector' 'selectedSource' 'expectedMethodHash' 'newSelector')
]

{ #category : 'private - source' }
KGMethodExtractRefactoringAdapter >> sha256: aString [
	<arg: #aString type: #String>
	<return: #String>
	^ (SHA256 hashMessage: aString utf8Encoded) hex
]

{ #category : 'catalog' }
KGMethodExtractRefactoringAdapter >> targetKind [ <return: #String> ^ 'selection'
]
