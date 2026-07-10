"
Parser and declaration extractor for the Kotlin subset used by the sample files.

The parser extracts packages, imports, type aliases, classes, interfaces, objects,
and functions. Function bodies and property initializers are skipped with balanced
delimiter scanning; they are intentionally not parsed as Kotlin expressions.

- Slots
  - source <#String> parsing - Source text accepted by {{gtClass:KGKotlinGrammar}}.
  - index <#Integer> parsing - Current one-based scanner index.
- Public API
  - {{gtMethod:KGKotlinParser class>>#parse:}} - Parse Kotlin source text into a {{gtClass:KGKotlinFile}}.
  - {{gtMethod:KGKotlinParser class>>#parseFile:}} - Parse a Kotlin source file reference.
  - {{gtMethod:KGKotlinParser>>#parse:}} - Parse Kotlin source text into a {{gtClass:KGKotlinFile}}.
"
Class {
	#name : 'KGKotlinParser',
	#superclass : 'Object',
	#instVars : [
		'source',
		'index'
	],
	#category : 'KlibGenGt-Kotlin-Parser',
	#package : 'KlibGenGt-Kotlin'
}

{ #category : 'instance creation' }
KGKotlinParser class >> parse: aString [
	<arg: #aString type: #String>
	<return: #KGKotlinFile>
	^ self new parse: aString
]

{ #category : 'instance creation' }
KGKotlinParser class >> parseFile: aFileReference [
	<arg: #aFileReference type: #(FileReference | String)>
	<return: #KGKotlinFile>
	^ self parse: aFileReference asFileReference contents
]

{ #category : 'parsing' }
KGKotlinParser >> parse: aString [
	<arg: #aString type: #String>
	<return: #KGKotlinFile>
	| packageName imports declarations |
	source := KGKotlinGrammar new parse: aString.
	index := 1.
	packageName := self parsePackageDirective.
	imports := self parseImportDirectives.
	declarations := self parseDeclarationsUntil: nil.
	^ KGKotlinFile
		packageName: packageName
		imports: imports
		declarations: declarations
]

{ #category : 'private - parsing' }
KGKotlinParser >> annotationAtIndex [
	<return: #String>
	| start |
	self currentChar = $@ ifFalse: [ ^ '' ].
	index := index + 1.
	start := index.
	self readQualifiedIdentifier.
	(self currentChar = $()
		ifTrue: [ self readBalancedFromCurrentOpen: $( close: $) ].
	^ (self stringFrom: start to: index - 1) trimBoth
]

{ #category : 'private - parsing' }
KGKotlinParser >> atEnd [
	<return: #Boolean>
	^ index > source size
]

{ #category : 'private - parsing' }
KGKotlinParser >> consumeKeyword: aString [
	<arg: #aString type: #String>
	<return: #Boolean>
	(self keywordAtIndex: aString) ifFalse: [ ^ false ].
	index := index + aString size.
	^ true
]

{ #category : 'private - accessing' }
KGKotlinParser >> currentChar [
	<return: #(Character?)>
	self atEnd ifTrue: [ ^ nil ].
	^ source at: index
]

{ #category : 'private - parsing' }
KGKotlinParser >> declarationsFromBodyIfPresent [
	<return: #Array>
	self skipTrivia.
	self currentChar = ${
		ifFalse: [ ^ #() ].
	index := index + 1.
	^ self parseDeclarationsUntil: $}
]

{ #category : 'private - parsing' }
KGKotlinParser >> identifierAtIndex [
	<return: #String>
	| start |
	(self isIdentifierStart: self currentChar) ifFalse: [ ^ '' ].
	start := index.
	[ self atEnd not and: [ self isIdentifierPart: self currentChar ] ]
		whileTrue: [ index := index + 1 ].
	^ self stringFrom: start to: index - 1
]

{ #category : 'private - testing' }
KGKotlinParser >> isIdentifierPart: aCharacter [
	<arg: #aCharacter type: #(Character?)>
	<return: #Boolean>
	aCharacter ifNil: [ ^ false ].
	^ aCharacter isAlphaNumeric or: [ aCharacter = $_ ]
]

{ #category : 'private - testing' }
KGKotlinParser >> isIdentifierStart: aCharacter [
	<arg: #aCharacter type: #(Character?)>
	<return: #Boolean>
	aCharacter ifNil: [ ^ false ].
	^ aCharacter isLetter or: [ aCharacter = $_ ]
]

{ #category : 'private - testing' }
KGKotlinParser >> isModifierWord: aString [
	<arg: #aString type: #String>
	<return: #Boolean>
	^ #( 'abstract' 'actual' 'annotation' 'companion' 'const' 'crossinline' 'data' 'enum' 'expect' 'external' 'final' 'infix' 'inline' 'inner' 'internal' 'lateinit' 'noinline' 'open' 'operator' 'out' 'override' 'private' 'protected' 'public' 'reified' 'sealed' 'suspend' 'tailrec' 'value' 'vararg' )
		includes: aString
]

{ #category : 'private - testing' }
KGKotlinParser >> keywordAtIndex: aString [
	<arg: #aString type: #String>
	<return: #Boolean>
	| before after |
	index + aString size - 1 > source size ifTrue: [ ^ false ].
	((source copyFrom: index to: index + aString size - 1) = aString)
		ifFalse: [ ^ false ].
	before := index = 1
		ifTrue: [ nil ]
		ifFalse: [ source at: index - 1 ].
	after := index + aString size > source size
		ifTrue: [ nil ]
		ifFalse: [ source at: index + aString size ].
	^ (self isIdentifierPart: before) not
		and: [ (self isIdentifierPart: after) not ]
]

{ #category : 'private - parsing' }
KGKotlinParser >> normalizeSupertype: aString [
	<arg: #aString type: #String>
	<return: #String>
	| trimmed paren |
	trimmed := aString trimBoth.
	paren := self firstTopLevelOpenParenIn: trimmed.
	paren = 0 ifTrue: [ ^ trimmed ].
	^ (trimmed copyFrom: 1 to: paren - 1) trimBoth
]

{ #category : 'private - parsing' }
KGKotlinParser >> parseDeclarationWithModifiers: modifierCollection annotations: annotationCollection [
	<arg: #modifierCollection type: #(Collection | Array)>
	<arg: #annotationCollection type: #(Collection | Array)>
	<return: #(KGKotlinDeclaration?)>
	(self consumeKeyword: 'typealias')
		ifTrue: [ ^ self parseTypeAliasWithModifiers: modifierCollection annotations: annotationCollection ].
	(self consumeKeyword: 'fun')
		ifTrue: [ ^ self parseFunctionWithModifiers: modifierCollection annotations: annotationCollection ].
	(self consumeKeyword: 'class')
		ifTrue: [ ^ self parseTypeKind: 'class' modifiers: modifierCollection annotations: annotationCollection ].
	(self consumeKeyword: 'interface')
		ifTrue: [ ^ self parseTypeKind: 'interface' modifiers: modifierCollection annotations: annotationCollection ].
	(self consumeKeyword: 'object')
		ifTrue: [ ^ self parseTypeKind: 'object' modifiers: modifierCollection annotations: annotationCollection ].
	self skipUnknownConstruct.
	^ nil
]

{ #category : 'private - parsing' }
KGKotlinParser >> parseDeclarationPrefix [
	<return: #Array>
	| annotations modifiers keepGoing word |
	annotations := OrderedCollection new.
	modifiers := OrderedCollection new.
	keepGoing := true.
	[ keepGoing ] whileTrue: [
		self skipTrivia.
		self currentChar = $@
			ifTrue: [
				annotations add: self annotationAtIndex.
				keepGoing := true ]
			ifFalse: [
				word := self peekIdentifier.
				(self isModifierWord: word)
					ifTrue: [
						modifiers add: self identifierAtIndex.
						keepGoing := true ]
					ifFalse: [ keepGoing := false ] ] ].
	^ { modifiers asArray. annotations asArray }
]

{ #category : 'private - parsing' }
KGKotlinParser >> parseDeclarationsUntil: terminatorOrNil [
	<arg: #terminatorOrNil type: #(Character?)>
	<return: #Array>
	| declarations prefix declaration |
	declarations := OrderedCollection new.
	[
		self skipTrivia.
		self atEnd not
			and: [
				terminatorOrNil isNil
					or: [ self currentChar ~= terminatorOrNil ] ] ]
		whileTrue: [
			prefix := self parseDeclarationPrefix.
			declaration := self
				parseDeclarationWithModifiers: prefix first
				annotations: prefix second.
			declaration ifNotNil: [ declarations add: declaration ] ].
	terminatorOrNil ifNotNil: [
		self currentChar = terminatorOrNil
			ifTrue: [ index := index + 1 ] ].
	^ declarations asArray
]

{ #category : 'private - parsing' }
KGKotlinParser >> parseFunctionWithModifiers: modifierCollection annotations: annotationCollection [
	<arg: #modifierCollection type: #(Collection | Array)>
	<arg: #annotationCollection type: #(Collection | Array)>
	<return: #KGKotlinFunctionDeclaration>
	| signatureStart signature parametersText parameters returnType dot receiver name |
	self skipTrivia.
	self currentChar = $<
		ifTrue: [ self readBalancedFromCurrentOpen: $< close: $> ].
	self skipTrivia.
	signatureStart := index.
	self scanUntilTopLevel: $(.
	signature := (self stringFrom: signatureStart to: index - 1) trimBoth.
	parametersText := self readBalancedFromCurrentOpen: $( close: $).
	parameters := self parseParametersFrom: parametersText.
	self skipTrivia.
	returnType := ''.
	self currentChar = $:
		ifTrue: [
			index := index + 1.
			returnType := (self readHeaderTailUntilAnyOf: { $=. ${. Character cr. Character lf }) trimBoth ].
	self skipTrivia.
	self currentChar = ${
		ifTrue: [ self readBalancedFromCurrentOpen: ${ close: $} ]
		ifFalse: [
			self currentChar = $=
				ifTrue: [ self skipExpressionInitializer ] ].
	dot := self lastDotIndexIn: signature.
	dot = 0
		ifTrue: [
			receiver := nil.
			name := signature ]
		ifFalse: [
			receiver := (signature copyFrom: 1 to: dot - 1) trimBoth.
			name := (signature copyFrom: dot + 1 to: signature size) trimBoth ].
	^ KGKotlinFunctionDeclaration
		name: name
		receiver: receiver
		modifiers: modifierCollection
		annotations: annotationCollection
		parameters: parameters
		returnType: returnType
]

{ #category : 'private - parsing' }
KGKotlinParser >> parseImportDirectives [
	<return: #Array>
	| imports line |
	imports := OrderedCollection new.
	[
		self skipTrivia.
		self keywordAtIndex: 'import' ]
		whileTrue: [
			self consumeKeyword: 'import'.
			line := self readUntilLineEnd trimBoth.
			imports add: (self parseImportLine: line).
			self skipLineEnd ].
	^ imports asArray
]

{ #category : 'private - parsing' }
KGKotlinParser >> parseImportLine: aString [
	<arg: #aString type: #String>
	<return: #KGKotlinImport>
	| aliasIndex path alias wildcard |
	aliasIndex := aString findString: ' as ' startingAt: 1.
	aliasIndex = 0
		ifTrue: [
			path := aString.
			alias := nil ]
		ifFalse: [
			path := (aString copyFrom: 1 to: aliasIndex - 1) trimBoth.
			alias := (aString copyFrom: aliasIndex + 4 to: aString size) trimBoth ].
	wildcard := path endsWith: '.*'.
	wildcard ifTrue: [ path := path copyFrom: 1 to: path size - 2 ].
	^ KGKotlinImport path: path wildcard: wildcard alias: alias
]

{ #category : 'private - parsing' }
KGKotlinParser >> parsePackageDirective [
	<return: #String>
	| packageName |
	self skipTrivia.
	(self consumeKeyword: 'package')
		ifFalse: [ ^ '' ].
	packageName := self readUntilLineEnd trimBoth.
	self skipLineEnd.
	^ packageName
]

{ #category : 'private - parsing' }
KGKotlinParser >> parseParameterFrom: aString [
	<arg: #aString type: #String>
	<return: #(KGKotlinParameter?)>
	| left colon before type property words name |
	left := (self textBeforeTopLevelEquals: aString) trimBoth.
	left := self stripLeadingAnnotationsAndModifiersFromParameter: left.
	left isEmpty ifTrue: [ ^ nil ].
	colon := self firstTopLevelColonIn: left.
	colon = 0 ifTrue: [ ^ nil ].
	before := (left copyFrom: 1 to: colon - 1) trimBoth.
	type := (left copyFrom: colon + 1 to: left size) trimBoth.
	words := before substrings.
	words isEmpty ifTrue: [ ^ nil ].
	property := nil.
	((words includes: 'val') or: [ words includes: 'var' ])
		ifTrue: [
			property := (words includes: 'val')
				ifTrue: [ 'val' ]
				ifFalse: [ 'var' ].
			name := words last ]
		ifFalse: [ name := words last ].
	^ KGKotlinParameter name: name type: type property: property
]

{ #category : 'private - parsing' }
KGKotlinParser >> parseParametersFrom: parenthesizedString [
	<arg: #parenthesizedString type: #String>
	<return: #Array>
	| inner parameters |
	parenthesizedString size <= 2 ifTrue: [ ^ #() ].
	inner := parenthesizedString copyFrom: 2 to: parenthesizedString size - 1.
	parameters := OrderedCollection new.
	(self splitTopLevel: inner by: $,) do: [ :each |
		| parameter |
		parameter := self parseParameterFrom: each.
		parameter ifNotNil: [ parameters add: parameter ] ].
	^ parameters asArray
]

{ #category : 'private - parsing' }
KGKotlinParser >> parseTypeAliasWithModifiers: modifierCollection annotations: annotationCollection [
	<arg: #modifierCollection type: #(Collection | Array)>
	<arg: #annotationCollection type: #(Collection | Array)>
	<return: #KGKotlinTypeAliasDeclaration>
	| name typeParameters targetType |
	self skipTrivia.
	name := self identifierAtIndex.
	self skipTrivia.
	typeParameters := ''.
	self currentChar = $<
		ifTrue: [ typeParameters := self readBalancedFromCurrentOpen: $< close: $> ].
	self skipTrivia.
	self currentChar = $=
		ifTrue: [ index := index + 1 ].
	targetType := self readUntilLineEnd trimBoth.
	^ KGKotlinTypeAliasDeclaration
		name: name
		modifiers: modifierCollection
		annotations: annotationCollection
		typeParameters: typeParameters
		targetType: targetType
]

{ #category : 'private - parsing' }
KGKotlinParser >> parseTypeKind: kindString modifiers: modifierCollection annotations: annotationCollection [
	<arg: #kindString type: #String>
	<arg: #modifierCollection type: #(Collection | Array)>
	<arg: #annotationCollection type: #(Collection | Array)>
	<return: #KGKotlinTypeDeclaration>
	| name typeParameters parameters supertypes tail nestedDeclarations |
	self skipTrivia.
	name := self identifierAtIndex.
	(name isEmpty and: [
		kindString = 'object' and: [ modifierCollection includes: 'companion' ] ])
		ifTrue: [ name := 'companion' ].
	self skipTrivia.
	typeParameters := ''.
	self currentChar = $<
		ifTrue: [ typeParameters := self readBalancedFromCurrentOpen: $< close: $> ].
	self skipTrivia.
	parameters := #().
	self currentChar = $(
		ifTrue: [ parameters := self parseParametersFrom: (self readBalancedFromCurrentOpen: $( close: $)) ].
	self skipTrivia.
	supertypes := #().
	self currentChar = $:
		ifTrue: [
			index := index + 1.
			tail := self readHeaderTailUntilAnyOf: { ${. Character cr. Character lf }.
			supertypes := (self splitTopLevel: tail by: $,)
				collect: [ :each | self normalizeSupertype: each ]
				thenSelect: [ :each | each notEmpty ] ].
	nestedDeclarations := self declarationsFromBodyIfPresent.
	^ KGKotlinTypeDeclaration
		kind: kindString
		name: name
		modifiers: modifierCollection
		annotations: annotationCollection
		typeParameters: typeParameters
		parameters: parameters
		supertypes: supertypes
		declarations: nestedDeclarations
]

{ #category : 'private - accessing' }
KGKotlinParser >> peekIdentifier [
	<return: #String>
	| saved word |
	saved := index.
	word := self identifierAtIndex.
	index := saved.
	^ word
]

{ #category : 'private - parsing' }
KGKotlinParser >> readBalancedFromCurrentOpen: openCharacter close: closeCharacter [
	<arg: #openCharacter type: #Character>
	<arg: #closeCharacter type: #Character>
	<return: #String>
	| start depth char |
	self currentChar = openCharacter ifFalse: [ ^ '' ].
	start := index.
	depth := 0.
	[ self atEnd ] whileFalse: [
		char := self currentChar.
		(char = $" or: [ char = $' ])
			ifTrue: [
				self skipQuotedString.
				char := nil ]
			ifFalse: [
				char = openCharacter ifTrue: [ depth := depth + 1 ].
				char = closeCharacter ifTrue: [
					depth := depth - 1.
					index := index + 1.
					depth = 0 ifTrue: [ ^ self stringFrom: start to: index - 1 ] ] ].
		char ifNotNil: [ index := index + 1 ] ].
	^ self stringFrom: start to: source size
]

{ #category : 'private - parsing' }
KGKotlinParser >> readHeaderTailUntilAnyOf: stopCharacters [
	<arg: #stopCharacters type: #Array>
	<return: #String>
	| start paren square angle char |
	start := index.
	paren := 0.
	square := 0.
	angle := 0.
	[ self atEnd ] whileFalse: [
		char := self currentChar.
		(char = $" or: [ char = $' ])
			ifTrue: [ self skipQuotedString ]
			ifFalse: [
				char = $( ifTrue: [ paren := paren + 1 ].
				char = $) ifTrue: [ paren := paren - 1 ].
				char = $[ ifTrue: [ square := square + 1 ].
				char = $] ifTrue: [ square := square - 1 ].
				char = $< ifTrue: [ angle := angle + 1 ].
				char = $> ifTrue: [ angle := angle - 1 ].
				(paren = 0 and: [ square = 0 and: [ angle = 0 and: [ stopCharacters includes: char ] ] ])
					ifTrue: [ ^ self stringFrom: start to: index - 1 ].
				index := index + 1 ] ].
	^ self stringFrom: start to: source size
]

{ #category : 'private - parsing' }
KGKotlinParser >> readQualifiedIdentifier [
	<return: #String>
	| start |
	start := index.
	[ self atEnd not and: [
		(self isIdentifierPart: self currentChar)
			or: [ self currentChar = $. ] ] ]
		whileTrue: [ index := index + 1 ].
	^ self stringFrom: start to: index - 1
]

{ #category : 'private - parsing' }
KGKotlinParser >> readUntilLineEnd [
	<return: #String>
	| start |
	self skipHorizontalWhitespace.
	start := index.
	[ self atEnd not and: [
		self currentChar ~= Character cr and: [
			self currentChar ~= Character lf ] ] ]
		whileTrue: [ index := index + 1 ].
	^ self stringFrom: start to: index - 1
]

{ #category : 'private - parsing' }
KGKotlinParser >> scanUntilTopLevel: aCharacter [
	<arg: #aCharacter type: #Character>
	<return: #Integer>
	| paren square angle char |
	paren := 0.
	square := 0.
	angle := 0.
	[ self atEnd ] whileFalse: [
		char := self currentChar.
		(char = $" or: [ char = $' ])
			ifTrue: [ self skipQuotedString ]
			ifFalse: [
				(char = aCharacter and: [ paren = 0 and: [ square = 0 and: [ angle = 0 ] ] ])
					ifTrue: [ ^ index ].
				char = $( ifTrue: [ paren := paren + 1 ].
				char = $) ifTrue: [ paren := paren - 1 ].
				char = $[ ifTrue: [ square := square + 1 ].
				char = $] ifTrue: [ square := square - 1 ].
				char = $< ifTrue: [ angle := angle + 1 ].
				char = $> ifTrue: [ angle := angle - 1 ].
				index := index + 1 ] ].
	^ index
]

{ #category : 'private - parsing' }
KGKotlinParser >> skipBlockComment [
	<return: #String>
	| end |
	end := source findString: '*/' startingAt: index + 2.
	end = 0
		ifTrue: [ index := source size + 1 ]
		ifFalse: [ index := end + 2 ].
	^ ''
]

{ #category : 'private - parsing' }
KGKotlinParser >> skipExpressionInitializer [
	<return: #String>
	| paren square brace angle char |
	paren := 0.
	square := 0.
	brace := 0.
	angle := 0.
	index := index + 1.
	[ self atEnd ] whileFalse: [
		char := self currentChar.
		(char = $" or: [ char = $' ])
			ifTrue: [ self skipQuotedString ]
			ifFalse: [
				char = $( ifTrue: [ paren := paren + 1 ].
				char = $) ifTrue: [ paren := paren - 1 ].
				char = $[ ifTrue: [ square := square + 1 ].
				char = $] ifTrue: [ square := square - 1 ].
				char = ${ ifTrue: [ brace := brace + 1 ].
				char = $} ifTrue: [ brace := brace - 1 ].
				char = $< ifTrue: [ angle := angle + 1 ].
				char = $> ifTrue: [ angle := angle - 1 ].
				((char = Character cr or: [ char = Character lf ])
					and: [ paren = 0 and: [ square = 0 and: [ brace = 0 and: [ angle = 0 ] ] ] ])
					ifTrue: [ ^ '' ].
				index := index + 1 ] ].
	^ ''
]

{ #category : 'private - parsing' }
KGKotlinParser >> skipHorizontalWhitespace [
	<return: #Integer>
	[ self atEnd not and: [
		self currentChar = Character space or: [
			self currentChar = Character tab ] ] ]
		whileTrue: [ index := index + 1 ].
	^ index
]

{ #category : 'private - parsing' }
KGKotlinParser >> skipLineComment [
	<return: #String>
	[ self atEnd not and: [
		self currentChar ~= Character cr and: [
			self currentChar ~= Character lf ] ] ]
		whileTrue: [ index := index + 1 ].
	^ ''
]

{ #category : 'private - parsing' }
KGKotlinParser >> skipLineEnd [
	<return: #Integer>
	self currentChar = Character cr ifTrue: [ index := index + 1 ].
	self currentChar = Character lf ifTrue: [ index := index + 1 ].
	^ index
]

{ #category : 'private - parsing' }
KGKotlinParser >> skipQuotedString [
	<return: #String>
	| quote triple |
	quote := self currentChar.
	triple := quote = $" and: [
		index + 2 <= source size and: [
			(source at: index + 1) = $" and: [ (source at: index + 2) = $" ] ] ].
	triple
		ifTrue: [
			index := index + 3.
			[ index + 2 <= source size and: [
				((source at: index) = $" and: [
					(source at: index + 1) = $" and: [ (source at: index + 2) = $" ] ]) not ] ]
				whileTrue: [ index := index + 1 ].
			index := (index + 3) min: source size + 1.
			^ '' ].
	index := index + 1.
	[ self atEnd not and: [ self currentChar ~= quote ] ] whileTrue: [
		self currentChar = $\
			ifTrue: [ index := index + 2 ]
			ifFalse: [ index := index + 1 ] ].
	self atEnd ifFalse: [ index := index + 1 ].
	^ ''
]

{ #category : 'private - parsing' }
KGKotlinParser >> skipTrivia [
	<return: #Integer>
	| changed |
	changed := true.
	[ changed ] whileTrue: [
		changed := false.
		[ self atEnd not and: [ self currentChar isSeparator ] ]
			whileTrue: [
				index := index + 1.
				changed := true ].
		(self startsWith: '//' at: index)
			ifTrue: [
				self skipLineComment.
				changed := true ].
		(self startsWith: '/*' at: index)
			ifTrue: [
				self skipBlockComment.
				changed := true ] ].
	^ index
]

{ #category : 'private - parsing' }
KGKotlinParser >> skipUnknownConstruct [
	<return: #String>
	self atEnd ifTrue: [ ^ '' ].
	self currentChar = ${
		ifTrue: [
			self readBalancedFromCurrentOpen: ${ close: $}.
			^ '' ].
	self skipExpressionInitializer.
	^ ''
]

{ #category : 'private - parsing' }
KGKotlinParser >> splitTopLevel: aString by: separatorCharacter [
	<arg: #aString type: #String>
	<arg: #separatorCharacter type: #Character>
	<return: #Array>
	| parts start indexInString paren square brace angle char |
	parts := OrderedCollection new.
	start := 1.
	indexInString := 1.
	paren := 0.
	square := 0.
	brace := 0.
	angle := 0.
	[ indexInString <= aString size ] whileTrue: [
		char := aString at: indexInString.
		(char = $" or: [ char = $' ])
			ifTrue: [ indexInString := self skipQuotedStringIn: aString startingAt: indexInString ]
			ifFalse: [
				char = $( ifTrue: [ paren := paren + 1 ].
				char = $) ifTrue: [ paren := paren - 1 ].
				char = $[ ifTrue: [ square := square + 1 ].
				char = $] ifTrue: [ square := square - 1 ].
				char = ${ ifTrue: [ brace := brace + 1 ].
				char = $} ifTrue: [ brace := brace - 1 ].
				char = $< ifTrue: [ angle := angle + 1 ].
				char = $> ifTrue: [ angle := angle - 1 ].
				(char = separatorCharacter and: [
					paren = 0 and: [ square = 0 and: [ brace = 0 and: [ angle = 0 ] ] ] ])
					ifTrue: [
						parts add: ((aString copyFrom: start to: indexInString - 1) trimBoth).
						start := indexInString + 1 ].
				indexInString := indexInString + 1 ] ].
	start <= aString size
		ifTrue: [ parts add: ((aString copyFrom: start to: aString size) trimBoth) ].
	^ parts asArray
]

{ #category : 'private - testing' }
KGKotlinParser >> startsWith: prefixString at: startIndex [
	<arg: #prefixString type: #String>
	<arg: #startIndex type: #Integer>
	<return: #Boolean>
	startIndex + prefixString size - 1 > source size ifTrue: [ ^ false ].
	^ (source copyFrom: startIndex to: startIndex + prefixString size - 1) = prefixString
]

{ #category : 'private - strings' }
KGKotlinParser >> stringFrom: startIndex to: stopIndex [
	<arg: #startIndex type: #Integer>
	<arg: #stopIndex type: #Integer>
	<return: #String>
	stopIndex < startIndex ifTrue: [ ^ '' ].
	^ source copyFrom: startIndex to: stopIndex
]

{ #category : 'private - parsing' }
KGKotlinParser >> stripLeadingAnnotationsAndModifiersFromParameter: aString [
	<arg: #aString type: #String>
	<return: #String>
	| text done words |
	text := aString trimBoth.
	done := false.
	[ done ] whileFalse: [
		text := text trimBoth.
		(text beginsWith: '@')
			ifTrue: [
				| paren |
				paren := self firstTopLevelOpenParenIn: text.
				(paren > 0 and: [ (text findString: ')' startingAt: paren) > 0 ])
					ifTrue: [ text := (text copyFrom: (text findString: ')' startingAt: paren) + 1 to: text size) trimBoth ]
					ifFalse: [
						words := text substrings.
						words size <= 1
							ifTrue: [ text := '' ]
							ifFalse: [ text := (text copyFrom: words first size + 1 to: text size) trimBoth ] ] ]
			ifFalse: [
				words := text substrings.
				(words notEmpty and: [ self isModifierWord: words first ])
					ifTrue: [ text := (text copyFrom: words first size + 1 to: text size) trimBoth ]
					ifFalse: [ done := true ] ] ].
	^ text
]

{ #category : 'private - parsing' }
KGKotlinParser >> textBeforeTopLevelEquals: aString [
	<arg: #aString type: #String>
	<return: #String>
	| parts |
	parts := self splitTopLevel: aString by: $=.
	parts isEmpty ifTrue: [ ^ '' ].
	^ parts first
]

{ #category : 'private - parsing' }
KGKotlinParser >> firstTopLevelColonIn: aString [
	<arg: #aString type: #String>
	<return: #Integer>
	^ self firstTopLevelCharacter: $: in: aString
]

{ #category : 'private - parsing' }
KGKotlinParser >> firstTopLevelOpenParenIn: aString [
	<arg: #aString type: #String>
	<return: #Integer>
	^ self firstTopLevelCharacter: $( in: aString
]

{ #category : 'private - parsing' }
KGKotlinParser >> firstTopLevelCharacter: targetCharacter in: aString [
	<arg: #targetCharacter type: #Character>
	<arg: #aString type: #String>
	<return: #Integer>
	| paren square brace angle position char |
	paren := 0.
	square := 0.
	brace := 0.
	angle := 0.
	position := 1.
	[ position <= aString size ] whileTrue: [
		char := aString at: position.
		(char = $" or: [ char = $' ])
			ifTrue: [ position := self skipQuotedStringIn: aString startingAt: position ]
			ifFalse: [
				(char = targetCharacter and: [
					paren = 0 and: [ square = 0 and: [ brace = 0 and: [ angle = 0 ] ] ] ])
					ifTrue: [ ^ position ].
				char = $( ifTrue: [ paren := paren + 1 ].
				char = $) ifTrue: [ paren := paren - 1 ].
				char = $[ ifTrue: [ square := square + 1 ].
				char = $] ifTrue: [ square := square - 1 ].
				char = ${ ifTrue: [ brace := brace + 1 ].
				char = $} ifTrue: [ brace := brace - 1 ].
				char = $< ifTrue: [ angle := angle + 1 ].
				char = $> ifTrue: [ angle := angle - 1 ].
				position := position + 1 ] ].
	^ 0
]

{ #category : 'private - parsing' }
KGKotlinParser >> lastDotIndexIn: aString [
	<arg: #aString type: #String>
	<return: #Integer>
	| position |
	position := aString size.
	[ position > 0 ] whileTrue: [
		(aString at: position) = $. ifTrue: [ ^ position ].
		position := position - 1 ].
	^ 0
]

{ #category : 'private - parsing' }
KGKotlinParser >> skipQuotedStringIn: aString startingAt: startIndex [
	<arg: #aString type: #String>
	<arg: #startIndex type: #Integer>
	<return: #Integer>
	| quote position triple |
	quote := aString at: startIndex.
	triple := quote = $" and: [
		startIndex + 2 <= aString size and: [
			(aString at: startIndex + 1) = $" and: [ (aString at: startIndex + 2) = $" ] ] ].
	triple
		ifTrue: [
			position := startIndex + 3.
			[ position + 2 <= aString size and: [
				((aString at: position) = $" and: [
					(aString at: position + 1) = $" and: [ (aString at: position + 2) = $" ] ]) not ] ]
				whileTrue: [ position := position + 1 ].
			^ (position + 3) min: aString size + 1 ].
	position := startIndex + 1.
	[ position <= aString size and: [ (aString at: position) ~= quote ] ] whileTrue: [
		(aString at: position) = $\
			ifTrue: [ position := position + 2 ]
			ifFalse: [ position := position + 1 ] ].
	^ (position + 1) min: aString size + 1
]
