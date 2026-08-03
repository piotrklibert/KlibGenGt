"
PetitParser2 grammar for the simplified legacy HTML subset.

- Slots
  - document <#PP2Node> grammar - Grammar production for a full fragment.
  - node <#PP2Node> grammar - Grammar production for one parsed node.
  - extensionNode <#PP2Node> grammar - Extension hook production; subclasses override to add non-HTML constructs.
  - element <#PP2Node> grammar - Grammar production for paired tags.
  - selfClosingElement <#PP2Node> grammar - Grammar production for `<tag/>` elements.
  - openTag <#PP2Node> grammar - Grammar production for opening tags.
  - closeTag <#PP2Node> grammar - Grammar production for closing tags.
  - tagName <#PP2Node> grammar - Grammar production for tag and attribute names.
  - attributes <#PP2Node> grammar - Grammar production for all attributes on a tag.
  - attribute <#PP2Node> grammar - Grammar production for one attribute.
  - attributeName <#PP2Node> grammar - Grammar production for attribute names.
  - attributeValue <#PP2Node> grammar - Grammar production for attribute values.
  - doubleQuotedAttributeValue <#PP2Node> grammar - Grammar production for double-quoted attributes.
  - singleQuotedAttributeValue <#PP2Node> grammar - Grammar production for single-quoted attributes.
  - unquotedAttributeValue <#PP2Node> grammar - Grammar production for unquoted attributes.
  - text <#PP2Node> grammar - Grammar production for plain text.
- Public API
  - {{gtMethod:KGHtmlGrammar>>#start}} - Answer the parser start production.
  - {{gtMethod:KGHtmlGrammar>>#extensionNode}} - Extension hook for subclasses that parse non-HTML constructs.
"
Class {
	#name : 'KGHtmlGrammar',
	#superclass : 'PP2CompositeNode',
	#instVars : [
		'document',
		'node',
		'extensionNode',
		'element',
		'selfClosingElement',
		'openTag',
		'closeTag',
		'tagName',
		'attributes',
		'attribute',
		'attributeName',
		'attributeValue',
		'doubleQuotedAttributeValue',
		'singleQuotedAttributeValue',
		'unquotedAttributeValue',
		'text'
	],
	#category : 'KlibGenGt-Core-LegacyHtml',
	#package : 'KlibGenGt-Core',
	#tag : 'LegacyHtml'
}

{ #category : 'grammar' }
KGHtmlGrammar >> attribute [
	<return: #PP2Node>
	^ (attributeName trim , ($= asPParser trim , attributeValue) optional)
		==> [ :node |
			node first -> (node second
				ifNil: [ '' ]
				ifNotNil: [ node second second ]) ]
]

{ #category : 'grammar' }
KGHtmlGrammar >> attributeName [
	<return: #PP2Node>
	^ tagName
]

{ #category : 'grammar' }
KGHtmlGrammar >> attributeValue [
	<return: #PP2Node>
	^ doubleQuotedAttributeValue / singleQuotedAttributeValue / unquotedAttributeValue
]

{ #category : 'grammar' }
KGHtmlGrammar >> attributes [
	<return: #PP2Node>
	^ (#space asPParser plus , attribute) star
		==> [ :nodes |
			| dictionary |
			dictionary := OrderedDictionary new.
			nodes do: [ :each | dictionary add: each second ].
			dictionary ]
]

{ #category : 'grammar' }
KGHtmlGrammar >> closeTag [
	<return: #PP2Node>
	^ '</' asPParser , tagName trim , $> asPParser ==> #second
]

{ #category : 'accessing' }
KGHtmlGrammar >> document [
	<return: #PP2Node>
	^ node star end
]

{ #category : 'grammar' }
KGHtmlGrammar >> doubleQuotedAttributeValue [
	<return: #PP2Node>
	^ $" asPParser , $" asPParser negate star flatten , $" asPParser ==> #second
]

{ #category : 'grammar' }
KGHtmlGrammar >> element [
	<return: #PP2Node>
	^ openTag , node star , closeTag
]

{ #category : 'extension' }
KGHtmlGrammar >> extensionNode [
	<return: #PP2Node>
	^ PP2FailingNode new
]

{ #category : 'accessing' }
KGHtmlGrammar >> node [
	<return: #PP2Node>
	^ extensionNode / selfClosingElement / element / text
]

{ #category : 'grammar' }
KGHtmlGrammar >> openTag [
	<return: #PP2Node>
	^ $< asPParser , tagName , attributes , $> asPParser
		==> [ :node | { node second. node third } ]
]

{ #category : 'grammar' }
KGHtmlGrammar >> selfClosingElement [
	<return: #PP2Node>
	^ $< asPParser , tagName , attributes , '/>' asPParser
		==> [ :node | { node second. node third } ]
]

{ #category : 'grammar' }
KGHtmlGrammar >> singleQuotedAttributeValue [
	<return: #PP2Node>
	^ $' asPParser , $' asPParser negate star flatten , $' asPParser ==> #second
]

{ #category : 'accessing' }
KGHtmlGrammar >> start [
	<return: #PP2Node>
	^ document
]

{ #category : 'grammar' }
KGHtmlGrammar >> tagName [
	<return: #PP2Node>
	^ (#letter asPParser / #digit asPParser / $- asPParser / $_ asPParser / $: asPParser) plus flatten
]

{ #category : 'grammar' }
KGHtmlGrammar >> text [
	<return: #PP2Node>
	^ $< asPParser negate plus flatten
]

{ #category : 'grammar' }
KGHtmlGrammar >> unquotedAttributeValue [
	<return: #PP2Node>
	^ ($> asPParser / $/ asPParser / #space asPParser) negate plus flatten
]
