"
Adapt one stable refactoring operation to the pinned Pharo refactoring API.

- Slots
  - none
- Public API
  - {{gtMethod:KGRefactoringAdapter>>#buildIn:request:}}
    Construct the model-backed transformation for a validated request.
  - {{gtMethod:KGRefactoringAdapter>>#descriptor}}
    Answer the JSON-compatible catalog description.
  - {{gtMethod:KGRefactoringAdapter>>#frameworkClassName}}
    Answer the pinned image class implementing the transformation.
  - {{gtMethod:KGRefactoringAdapter>>#identifier}}
    Answer the stable public operation identifier.
  - {{gtMethod:KGRefactoringAdapter>>#optionalArguments}}
    Answer optional adapter argument names.
  - {{gtMethod:KGRefactoringAdapter>>#requiredArguments}}
    Answer mandatory adapter argument names.
  - {{gtMethod:KGRefactoringAdapter>>#requiresScope}}
    Answer whether the request must provide an explicit scope.
  - {{gtMethod:KGRefactoringAdapter>>#safetyNotes}}
    Answer machine-readable safety properties for callers.
  - {{gtMethod:KGRefactoringAdapter>>#targetKind}}
    Answer the target kind used by applicability discovery.
  - {{gtMethod:KGRefactoringAdapter>>#version}}
    Answer the adapter version included in plan identity.
"
Class {
	#name : 'KGRefactoringAdapter',
	#superclass : 'Object',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'private - requests' }
KGRefactoringAdapter >> argumentsFrom: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	^ aRequest at: 'arguments' ifAbsent: [ Dictionary new ]
]

{ #category : 'building' }
KGRefactoringAdapter >> buildIn: aModel request: aRequest [
	<arg: #aModel type: #GtRBNamespace>
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #RBAbstractTransformation>
	^ self subclassResponsibility
]

{ #category : 'private - model' }
KGRefactoringAdapter >> classNamed: aName in: aModel [
	<arg: #aName type: #String>
	<arg: #aModel type: #GtRBNamespace>
	<return: #RBClass>
	| behavior |
	behavior := Smalltalk globals
		at: aName asSymbol
		ifAbsent: [ self error: 'unknown class: ', aName ].
	(behavior package name beginsWith: 'KlibGenGt-') ifFalse: [
		self error: 'refactoring targets are limited to KlibGenGt packages' ].
	^ aModel classFor: behavior
]

{ #category : 'catalog' }
KGRefactoringAdapter >> descriptor [
	<return: #(Dictionary<String, Any>)>
	^ OrderedDictionary new
		at: 'id' put: self identifier;
		at: 'version' put: self version;
		at: 'targetKind' put: self targetKind;
		at: 'requiredArguments' put: self requiredArguments;
		at: 'optionalArguments' put: self optionalArguments;
		at: 'requiresScope' put: self requiresScope;
		at: 'safety' put: self safetyNotes;
		at: 'frameworkClass' put: self frameworkClassName;
		at: 'status' put: 'supported';
		yourself
]

{ #category : 'catalog' }
KGRefactoringAdapter >> frameworkClassName [
	<return: #String>
	^ self subclassResponsibility
]

{ #category : 'catalog' }
KGRefactoringAdapter >> identifier [
	<return: #String>
	^ self subclassResponsibility
]

{ #category : 'private - requests' }
KGRefactoringAdapter >> methodClassFrom: arguments in: aModel [
	<arg: #arguments type: #(Dictionary<String, Any>)>
	<arg: #aModel type: #GtRBNamespace>
	<return: #RBClass>
	| modelClass side |
	modelClass := self classNamed: (self require: 'class' in: arguments) in: aModel.
	side := arguments at: 'side' ifAbsent: [ 'instance' ].
	side = 'instance' ifTrue: [ ^ modelClass ].
	side = 'class' ifTrue: [ ^ modelClass classSide ].
	self error: 'side must be instance or class'
]

{ #category : 'catalog' }
KGRefactoringAdapter >> optionalArguments [
	<return: #(Array<String>)>
	^ #()
]

{ #category : 'private - requests' }
KGRefactoringAdapter >> require: aKey in: aDictionary [
	<arg: #aKey type: #String>
	<arg: #aDictionary type: #(Dictionary<String, Any>)>
	<return: #Any>
	^ aDictionary at: aKey ifAbsent: [ self error: 'missing refactoring argument: ', aKey ]
]

{ #category : 'catalog' }
KGRefactoringAdapter >> requiredArguments [
	<return: #(Array<String>)>
	^ self subclassResponsibility
]

{ #category : 'catalog' }
KGRefactoringAdapter >> requiresScope [
	<return: #Boolean>
	^ false
]

{ #category : 'catalog' }
KGRefactoringAdapter >> safetyNotes [
	<return: #(Array<String>)>
	^ #('project-packages-only' 'preview-before-apply')
]

{ #category : 'catalog' }
KGRefactoringAdapter >> targetKind [
	<return: #String>
	^ self subclassResponsibility
]

{ #category : 'catalog' }
KGRefactoringAdapter >> version [
	<return: #Integer>
	^ 1
]
