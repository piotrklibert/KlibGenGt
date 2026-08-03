"
PetitParser2 entry grammar for Kotlin source text.

The declaration extractor in {{gtClass:KGKotlinParser}} performs the Kotlin-specific
scanning after this grammar accepts the source as one complete text. Keeping this
class as the PP2 boundary lets later work replace scanner pieces with richer
productions without changing the public parser API.

- Slots
  - sourceText <#PP2Node> grammar - Grammar production for a complete Kotlin source string.
- Public API
  - {{gtMethod:KGKotlinGrammar>>#start}} - Answer the parser start production.
  - {{gtMethod:KGKotlinGrammar>>#sourceText}} - Answer the complete-source production.
"
Class {
	#name : 'KGKotlinGrammar',
	#superclass : 'PP2CompositeNode',
	#instVars : [
		'sourceText'
	],
	#category : 'KlibGenGt-Kotlin-Parser',
	#package : 'KlibGenGt-Kotlin',
	#tag : 'Parser'
}

{ #category : 'accessing' }
KGKotlinGrammar >> sourceText [
	<return: #PP2Node>
	^ #any asPParser star flatten end
]

{ #category : 'accessing' }
KGKotlinGrammar >> start [
	<return: #PP2Node>
	^ sourceText
]
