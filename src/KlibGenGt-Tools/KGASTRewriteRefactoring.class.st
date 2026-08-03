"
Apply a bounded `RBParseTreeRewriter` over an explicit project source scope.

- Slots
  - `request` (`#(Dictionary<String, Any>)`, `configuration`) - Validated rewrite request.
  - `matchCount` (`#Integer`, `results`) - Number of methods changed by the rewrite.
- Public API
  - {{gtMethod:KGASTRewriteRefactoring class>>#model:request:}}
    Construct a model-backed rewrite from one structured request.
  - {{gtMethod:KGASTRewriteRefactoring>>#containsPatternBlocks}}
    Answer whether search or replacement contains executable pattern blocks.
  - {{gtMethod:KGASTRewriteRefactoring>>#matchCount}}
    Answer the number of transformed methods.
"
Class {
	#name : 'KGASTRewriteRefactoring',
	#superclass : 'RBRefactoring',
	#instVars : [
		'request',
		'matchCount'
	],
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'instance creation' }
KGASTRewriteRefactoring class >> model: aModel request: aRequest [
	<arg: #aModel type: #GtRBNamespace>
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #KGASTRewriteRefactoring>
	^ self new model: aModel; initializeRequest: aRequest
]

{ #category : 'private - scope' }
KGASTRewriteRefactoring >> behaviorNamed: className side: side [
	<arg: #className type: #String>
	<arg: #side type: #String>
	<return: #Behavior>
	| behavior |
	behavior := Smalltalk globals
		at: className asSymbol
		ifAbsent: [ self error: 'unknown class in rewrite scope: ', className ].
	(behavior package name beginsWith: 'KlibGenGt-') ifFalse: [
		self error: 'rewrite scope is limited to KlibGenGt packages' ].
	(#('instance' 'class') includes: side) ifFalse: [
		self error: 'rewrite method side must be instance or class' ].
	^ side = 'class' ifTrue: [ behavior class ] ifFalse: [ behavior ]
]

{ #category : 'testing' }
KGASTRewriteRefactoring >> containsPatternBlocks [
	<return: #Boolean>
	| arguments kind parser searchTree replaceTree nodes |
	arguments := request at: 'arguments'.
	kind := arguments at: 'patternKind' ifAbsent: [ 'expression' ].
	parser := kind = 'method'
		ifTrue: [ [ :source | RBParser parseRewriteMethod: source ] ]
		ifFalse: [ [ :source | RBParser parseRewriteExpression: source ] ].
	searchTree := parser value: (arguments at: 'search').
	replaceTree := parser value: (arguments at: 'replace').
	nodes := { searchTree. replaceTree }, searchTree allChildren, replaceTree allChildren.
	^ nodes anySatisfy: [ :node | node isKindOf: RBPatternBlockNode ]
]

{ #category : 'private - scope' }
KGASTRewriteRefactoring >> explicitMethodsFrom: scope [
	<arg: #scope type: #(Dictionary<String, Any>)>
	<return: #(Array<CompiledMethod>)>
	^ ((scope at: 'methods') collect: [ :entry |
		| behavior selector |
		behavior := self
			behaviorNamed: (entry at: 'class')
			side: (entry at: 'side' ifAbsent: [ 'instance' ]).
		selector := (entry at: 'selector') asSymbol.
		behavior compiledMethodAt: selector ifAbsent: [ self error: 'method not found in rewrite scope' ] ]) asArray
]

{ #category : 'initialization' }
KGASTRewriteRefactoring >> initializeRequest: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #KGASTRewriteRefactoring>
	request := aRequest.
	matchCount := 0.
	^ self
]

{ #category : 'accessing' }
KGASTRewriteRefactoring >> matchCount [
	<return: #Integer>
	^ matchCount
]

{ #category : 'private - scope' }
KGASTRewriteRefactoring >> methodsFromScope [
	<return: #(Array<CompiledMethod>)>
	| scope classNames packages classes methods sides |
	scope := request at: 'scope' ifAbsent: [ self error: 'rewrite.ast requires an explicit scope' ].
	(scope includesKey: 'methods') ifTrue: [ ^ self explicitMethodsFrom: scope ].
	classNames := scope at: 'classes' ifAbsent: [ #() ].
	packages := scope at: 'packages' ifAbsent: [ #() ].
	(classNames isEmpty and: [ packages isEmpty ]) ifTrue: [ self error: 'rewrite scope requires packages, classes, or methods' ].
	classes := OrderedCollection new.
	classNames do: [ :name |
		classes add: (self behaviorNamed: name side: 'instance') ].
	packages do: [ :pattern |
		| prefix |
		prefix := (pattern endsWith: '*') ifTrue: [ pattern allButLast ] ifFalse: [ pattern ].
		(prefix beginsWith: 'KlibGenGt-') ifFalse: [
			self error: 'rewrite package scope is limited to KlibGenGt packages' ].
		(RPackageOrganizer default packages select: [ :package |
			(pattern endsWith: '*')
				ifTrue: [ package name beginsWith: prefix ]
				ifFalse: [ package name = pattern ] ]) do: [ :package |
			classes addAll: package definedClasses ] ].
	sides := scope at: 'sides' ifAbsent: [ #('instance' 'class') ].
	(sides allSatisfy: [ :side | #('instance' 'class') includes: side ]) ifFalse: [
		self error: 'rewrite sides must contain only instance or class' ].
	methods := OrderedCollection new.
	classes asSet do: [ :behavior |
		(sides includes: 'instance') ifTrue: [ methods addAll: behavior methods ].
		(sides includes: 'class') ifTrue: [ methods addAll: behavior class methods ] ].
	^ methods asArray
]

{ #category : 'preconditions' }
KGASTRewriteRefactoring >> preconditions [
	<return: #RBCondition>
	^ RBCondition true
]

{ #category : 'transforming' }
KGASTRewriteRefactoring >> privateTransform [
	<return: #KGASTRewriteRefactoring>
	| arguments methods limits maxMethods maxMatches kind |
	arguments := request at: 'arguments'.
	methods := self methodsFromScope.
	limits := request at: 'limits' ifAbsent: [ Dictionary new ].
	maxMethods := limits at: 'maxMethods' ifAbsent: [ 100 ].
	maxMatches := limits at: 'maxMatches' ifAbsent: [ 200 ].
	methods size > (1000 min: maxMethods) ifTrue: [ self error: 'rewrite method limit exceeded' ].
	kind := arguments at: 'patternKind' ifAbsent: [ 'expression' ].
	(#('expression' 'method') includes: kind) ifFalse: [ self error: 'patternKind must be expression or method' ].
	methods do: [ :method |
		| rewriter |
		rewriter := RBParseTreeRewriter new.
		kind = 'method'
			ifTrue: [ rewriter replaceMethod: (arguments at: 'search') with: (arguments at: 'replace') ]
			ifFalse: [ rewriter replace: (arguments at: 'search') with: (arguments at: 'replace') ].
		(rewriter executeTree: method ast copy) ifTrue: [
			matchCount := matchCount + 1.
			matchCount > (2000 min: maxMatches) ifTrue: [ self error: 'rewrite match limit exceeded' ].
			(model classFor: method methodClass) compileTree: rewriter tree ] ].
	^ self
]
