"
Parser layer that maps {{gtClass:KGHtmlGrammar}} productions into AST nodes.

- Slots
  - none
- Public API
  - {{gtMethod:KGHtmlParser class>>#parse:}} - Parse a simplified HTML fragment into a {{gtClass:KGHtmlDocument}}.
"
Class {
	#name : 'KGHtmlParser',
	#superclass : 'KGHtmlGrammar',
	#category : 'KlibGenGt-Core-LegacyHtml',
	#package : 'KlibGenGt-Core',
	#tag : 'LegacyHtml'
}

{ #category : 'instance creation' }
KGHtmlParser class >> parse: aString [
	<arg: #aString type: #String>
	<return: #KGHtmlDocument>
	^ self new parse: aString
]

{ #category : 'accessing' }
KGHtmlParser >> document [
	<return: #PP2Node>
	^ super document ==> [ :nodes | KGHtmlDocument children: nodes ]
]

{ #category : 'grammar' }
KGHtmlParser >> element [
	<return: #PP2Node>
	^ super element ==> [ :node |
		| open close |
		open := node first.
		close := node third.
		open first = close
			ifFalse: [
				self error: 'Mismatched closing tag: expected </' , open first , '> but found </' , close , '>' ].
		KGHtmlElement
			name: open first
			attributes: open second
			children: node second ]
]

{ #category : 'grammar' }
KGHtmlParser >> selfClosingElement [
	<return: #PP2Node>
	^ super selfClosingElement ==> [ :node |
		KGHtmlElement
			name: node first
			attributes: node second
			children: #() ]
]

{ #category : 'grammar' }
KGHtmlParser >> text [
	<return: #PP2Node>
	^ super text ==> [ :value | KGHtmlText text: value ]
]
