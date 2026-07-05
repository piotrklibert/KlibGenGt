"
Validate KlibGenGt documentation type expressions in class comments and method pragmas.

- Slots
  - none
- Public API
  - {{gtMethod:KGCheckTypePragmas>>#inClass:}} 
    Validate slot type comments and method type pragmas for one class.
  - {{gtMethod:KGCheckTypePragmas>>#inPackage:}} 
    Validate all defined classes in one package, excluding extension methods.
  - {{gtMethod:KGCheckTypePragmas>>#validateTypeLiteral:}} 
    Validate a compiled pragma type literal.
  - {{gtMethod:KGCheckTypePragmas>>#validateTypeString:}} 
    Validate a slot type string from a class comment.
"
Class {
	#name : 'KGCheckTypePragmas',
	#superclass : 'Object',
	#category : 'KlibGenGt-Environment',
	#package : 'KlibGenGt-Environment'
}

{ #category : 'checking' }
KGCheckTypePragmas >> inClass: aClass [
	<arg: #aClass type: #ClassDescription>
	<return: #(OrderedCollection<Dictionary>)>
	| results |
	results := OrderedCollection new.
	self
		typeStringsInCommentOf: aClass
		do: [ :typeString :line |
			results add: (self
				resultFor: aClass
				source: 'slot comment'
				type: typeString
				valid: (self validateTypeString: typeString)
				message: 'slot type on line: ' , line trimBoth) ].
	self methodsDefinedBy: aClass do: [ :method |
		self addMethodPragmaResultsFor: method in: aClass to: results ].
	^ results
]

{ #category : 'checking' }
KGCheckTypePragmas >> inPackage: aPackageOrName [
	<arg: #aPackageOrName type: #(RPackage | String | Symbol)>
	<return: #(OrderedCollection<Dictionary>)>
	| package |
	package := aPackageOrName isString
		ifTrue: [ RPackageOrganizer default packageNamed: aPackageOrName ]
		ifFalse: [
			aPackageOrName isSymbol
				ifTrue: [ RPackageOrganizer default packageNamed: aPackageOrName asString ]
				ifFalse: [ aPackageOrName ] ].
	^ package definedClasses
		inject: OrderedCollection new
		into: [ :results :class |
			results addAll: (self inClass: class).
			results ]
]

{ #category : 'checking' }
KGCheckTypePragmas >> validateTypeLiteral: aLiteral [
	<arg: #aLiteral type: #(Symbol | Array)>
	<return: #Boolean>
	aLiteral isSymbol ifTrue: [ ^ self isNominalTypeSymbol: aLiteral ].
	aLiteral isArray ifTrue: [ ^ self validateTypeArray: aLiteral asArray ].
	^ false
]

{ #category : 'checking' }
KGCheckTypePragmas >> validateTypeString: aString [
	<arg: #aString type: #String>
	<return: #Boolean>
	| tokens |
	tokens := self tokenizeTypeString: aString.
	tokens ifNil: [ ^ false ].
	^ self validateTypeLiteral: tokens
]

{ #category : 'private - results' }
KGCheckTypePragmas >> addMethodPragmaResultsFor: aCompiledMethod in: aClass to: results [
	<arg: #aCompiledMethod type: #CompiledMethod>
	<arg: #aClass type: #ClassDescription>
	<arg: #results type: #(OrderedCollection<Dictionary>)>
	<return: #(OrderedCollection<Dictionary>)>
	aCompiledMethod pragmas do: [ :pragma |
		pragma selector = #returns:
			ifTrue: [
				results add: (self
					resultFor: aClass
					source: aCompiledMethod methodClass name , '>>#' , aCompiledMethod selector asString , ' <return:>'
					type: pragma arguments first printString
					valid: false
					message: 'Use <return: Type>, not <returns: Type>.') ].
		pragma selector = #return:
			ifTrue: [
				| type |
				type := pragma arguments first.
				results add: (self
					resultFor: aClass
					source: aCompiledMethod methodClass name , '>>#' , aCompiledMethod selector asString , ' <return:>'
					type: type printString
					valid: (self validateTypeLiteral: type)
					message: 'return type') ].
		pragma selector = #arg:type:
			ifTrue: [
				| type argumentName |
				argumentName := pragma arguments first.
				type := pragma arguments second.
				results add: (self
					resultFor: aClass
					source: aCompiledMethod methodClass name , '>>#' , aCompiledMethod selector asString , ' <arg: ' , argumentName printString , ' type:>'
					type: type printString
					valid: (self validateTypeLiteral: type)
					message: 'argument type') ] ].
	^ results
]

{ #category : 'private - parsing' }
KGCheckTypePragmas >> arrayFrom: aCollection [
	<arg: #aCollection type: #Collection>
	<return: #Array>
	^ aCollection asArray
]

{ #category : 'private - parsing' }
KGCheckTypePragmas >> isNominalTypeSymbol: aSymbol [
	<arg: #aSymbol type: #Symbol>
	<return: #Boolean>
	| value base |
	(self specialTypeSymbols includes: aSymbol) ifTrue: [ ^ false ].
	value := aSymbol asString.
	value isEmpty ifTrue: [ ^ false ].
	base := (value endsWith: '?')
		ifTrue: [ value allButLast ]
		ifFalse: [ value ].
	base isEmpty ifTrue: [ ^ false ].
	^ base allSatisfy: [ :each |
		each isAlphaNumeric or: [ each = $_ or: [ each = $: ] ] ]
]

{ #category : 'private - parsing' }
KGCheckTypePragmas >> methodsDefinedBy: aClass do: aBlock [
	<arg: #aClass type: #ClassDescription>
	<arg: #aBlock type: #(CompiledMethod -> Object)>
	<return: #ClassDescription>
	aClass methodDictionary valuesDo: [ :method |
		method package = aClass package ifTrue: [ aBlock value: method ] ].
	aClass class methodDictionary valuesDo: [ :method |
		method package = aClass package ifTrue: [ aBlock value: method ] ].
	^ aClass
]

{ #category : 'private - results' }
KGCheckTypePragmas >> resultFor: aClass source: sourceString type: typeString valid: aBoolean message: messageString [
	<arg: #aClass type: #ClassDescription>
	<arg: #sourceString type: #String>
	<arg: #typeString type: #String>
	<arg: #aBoolean type: #Boolean>
	<arg: #messageString type: #String>
	<return: #Dictionary>
	^ OrderedDictionary new
		at: #class put: aClass name;
		at: #source put: sourceString;
		at: #type put: typeString;
		at: #valid put: aBoolean;
		at: #message put: messageString;
		yourself
]

{ #category : 'private - parsing' }
KGCheckTypePragmas >> specialTypeSymbols [
	<return: #Array>
	^ #( | < > , -> ? )
]

{ #category : 'private - parsing' }
KGCheckTypePragmas >> slotTypeEndIn: line startingAt: start [
	<arg: #line type: #String>
	<arg: #start type: #Integer>
	<return: #Integer>
	| depth index |
	depth := 0.
	index := start + 1.
	[ index <= line size ] whileTrue: [
		| char |
		char := line at: index.
		char = $( ifTrue: [ depth := depth + 1 ].
		char = $) ifTrue: [ depth := depth - 1 ].
		(char = $> and: [ depth = 0 ]) ifTrue: [ ^ index ].
		index := index + 1 ].
	^ 0
]

{ #category : 'private - parsing' }
KGCheckTypePragmas >> split: tokens by: separator [
	<arg: #tokens type: #Array>
	<arg: #separator type: #Symbol>
	<return: #(Array<Array>)>
	| groups current |
	groups := OrderedCollection new.
	current := OrderedCollection new.
	tokens do: [ :each |
		each = separator
			ifTrue: [
				groups add: current asArray.
				current := OrderedCollection new ]
			ifFalse: [ current add: each ] ].
	groups add: current asArray.
	^ groups asArray
]

{ #category : 'private - parsing' }
KGCheckTypePragmas >> tokenizeTypeString: aString [
	<arg: #aString type: #String>
	<return: #(Array | Symbol | UndefinedObject)>
	| trimmed inner |
	trimmed := aString trimBoth.
	(trimmed beginsWith: '#') ifFalse: [ ^ nil ].
	(trimmed beginsWith: '#(')
		ifFalse: [ ^ trimmed allButFirst asSymbol ].
	(trimmed endsWith: ')') ifFalse: [ ^ nil ].
	inner := trimmed copyFrom: 3 to: trimmed size - 1.
	^ self tokenizeTypeStringInner: inner
]

{ #category : 'private - parsing' }
KGCheckTypePragmas >> tokenizeTypeStringInner: aString [
	<arg: #aString type: #String>
	<return: #Array>
	| tokens stream |
	tokens := OrderedCollection new.
	stream := ReadStream on: aString.
	[ stream atEnd ] whileFalse: [
		| char |
		stream skipSeparators.
		stream atEnd ifFalse: [
			char := stream peek.
			(char = $()
				ifTrue: [
					stream next.
					tokens add: (self tokenizeTypeStringInner: (self upToMatchingParenFrom: stream)) ]
				ifFalse: [
					((#($| $< $> $, $*) includes: char)
						ifTrue: [ tokens add: stream next asString asSymbol ]
						ifFalse: [
							(char = $- and: [ stream peekFor: $- ])
								ifTrue: [
									stream peekFor: $>.
									tokens add: #'->' ]
								ifFalse: [ tokens add: (self upToTypeSeparatorFrom: stream) asSymbol ] ]) ] ] ].
	^ tokens asArray
]

{ #category : 'private - parsing' }
KGCheckTypePragmas >> typePartsFrom: tokens separatedBy: separator [
	<arg: #tokens type: #Array>
	<arg: #separator type: #Symbol>
	<return: #(Array<Array>)>
	^ (self split: tokens by: separator)
		reject: [ :each | each isEmpty ]
]

{ #category : 'private - parsing' }
KGCheckTypePragmas >> typeStringsInCommentOf: aClass do: aBlock [
	<arg: #aClass type: #ClassDescription>
	<arg: #aBlock type: #(String, String -> Object)>
	<return: #ClassDescription>
	aClass comment lines do: [ :line |
		| start stop |
		start := line indexOfSubCollection: '<#' startingAt: 1.
		start > 0 ifTrue: [
			stop := self slotTypeEndIn: line startingAt: start.
			stop > start ifTrue: [
				aBlock value: (line copyFrom: start + 1 to: stop - 1) value: line ] ] ].
	^ aClass
]

{ #category : 'private - parsing' }
KGCheckTypePragmas >> upToMatchingParenFrom: stream [
	<arg: #stream type: #ReadStream>
	<return: #String>
	| depth buffer |
	depth := 1.
	buffer := WriteStream on: String new.
	[ stream atEnd or: [ depth = 0 ] ] whileFalse: [
		| char |
		char := stream next.
		char = $( ifTrue: [ depth := depth + 1 ].
		char = $) ifTrue: [ depth := depth - 1 ].
		depth > 0 ifTrue: [ buffer nextPut: char ] ].
	^ buffer contents
]

{ #category : 'private - parsing' }
KGCheckTypePragmas >> upToTypeSeparatorFrom: stream [
	<arg: #stream type: #ReadStream>
	<return: #String>
	| buffer |
	buffer := WriteStream on: String new.
	[ stream atEnd or: [
		stream peek isSeparator or: [ #($| $< $> $, $( $) $*) includes: stream peek ] ] ]
		whileFalse: [ buffer nextPut: stream next ].
	^ buffer contents
]

{ #category : 'private - validation' }
KGCheckTypePragmas >> validateBlockTypeArray: tokens [
	<arg: #tokens type: #Array>
	<return: #Boolean>
	| arrowIndex args return |
	arrowIndex := tokens indexOf: #'->'.
	arrowIndex = 0 ifTrue: [ ^ false ].
	return := tokens allButFirst: arrowIndex.
	return isEmpty ifTrue: [ ^ false ].
	(self validateTypeArray: return) ifFalse: [ ^ false ].
	args := tokens first: arrowIndex - 1.
	args isEmpty ifTrue: [ ^ true ].
	^ (self typePartsFrom: args separatedBy: #,) allSatisfy: [ :each |
		self validateBlockTypeArgument: each ]
]

{ #category : 'private - validation' }
KGCheckTypePragmas >> validateBlockTypeArgument: tokens [
	<arg: #tokens type: #Array>
	<return: #Boolean>
	(tokens size = 2 and: [ tokens second = #* and: [ tokens first isSymbol ] ])
		ifTrue: [ ^ self isNominalTypeSymbol: tokens first ].
	^ self validateTypeArray: tokens
]

{ #category : 'private - validation' }
KGCheckTypePragmas >> validateParametricTypeArray: tokens [
	<arg: #tokens type: #Array>
	<return: #Boolean>
	| closeIndex params |
	(tokens size >= 4 and: [ tokens first isSymbol and: [ tokens second = #< and: [ tokens last = #> ] ] ])
		ifFalse: [ ^ false ].
	(self isNominalTypeSymbol: tokens first) ifFalse: [ ^ false ].
	closeIndex := tokens size.
	params := tokens copyFrom: 3 to: closeIndex - 1.
	params isEmpty ifTrue: [ ^ false ].
	^ (self typePartsFrom: params separatedBy: #,) allSatisfy: [ :each |
		self validateTypeArray: each ]
]

{ #category : 'private - validation' }
KGCheckTypePragmas >> validateTypeArray: tokens [
	<arg: #tokens type: #Array>
	<return: #Boolean>
	tokens isEmpty ifTrue: [ ^ false ].
	(tokens includes: #'->') ifTrue: [ ^ self validateBlockTypeArray: tokens ].
	(tokens includes: #|) ifTrue: [
		^ (self typePartsFrom: tokens separatedBy: #|) allSatisfy: [ :each |
			self validateTypeArray: each ] ].
	(tokens includes: #<) ifTrue: [ ^ self validateParametricTypeArray: tokens ].
	(tokens size = 2 and: [ tokens second = #? and: [ tokens first isSymbol ] ])
		ifTrue: [ ^ self isNominalTypeSymbol: tokens first ].
	tokens size = 1 ifTrue: [
		| token |
		token := tokens first.
		token isSymbol ifTrue: [ ^ self isNominalTypeSymbol: token ].
		token isArray ifTrue: [ ^ self validateTypeArray: token ].
		^ false ].
	^ false
]
