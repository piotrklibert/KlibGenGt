"
SUnit coverage for simplified HTML and legacy post parsing.

- Slots
  - none
- Public API
  - none; test selectors are invoked by SUnit and document expected parser behavior.
"
Class {
	#name : 'KGHtmlParserTest',
	#superclass : 'TestCase',
	#category : 'KlibGenGt-Tests-LegacyHtml',
	#package : 'KlibGenGt-Tests'
}

{ #category : 'tests' }
KGHtmlParserTest >> testLegacyPostParserKeepsHtmlAroundCodeBlock [
	| document |
	document := KGLegacyPostParser parse: '<p>before</p>--kod=racket
(+ 1 2)
--/kod<p>after</p>'.
	self assert: document children size equals: 3.
	self assert: document children second isCodeBlock.
	self assert: document children third name equals: 'p'
]

{ #category : 'tests' }
KGHtmlParserTest >> testLegacyPostParserParsesCodeBlock [
	| document block |
	document := KGLegacyPostParser parse: '--kod=racket
(+ 1 2)
--/kod'.
	block := document children first.
	self assert: block isCodeBlock.
	self assert: block language equals: 'racket'.
	self assert: block code equals: '(+ 1 2)
'
]

{ #category : 'tests' }
KGHtmlParserTest >> testParsesAttributes [
	| document element |
	document := KGHtmlParser parse: '<a href="/posts/demo.html" title=''Demo'' data-id=42>Demo</a>'.
	element := document children first.
	self assert: element name equals: 'a'.
	self assert: (element attributeAt: 'href') equals: '/posts/demo.html'.
	self assert: (element attributeAt: 'title') equals: 'Demo'.
	self assert: (element attributeAt: 'data-id') equals: '42'
]

{ #category : 'tests' }
KGHtmlParserTest >> testParsesNestedElements [
	| document paragraph strong |
	document := KGHtmlParser parse: '<p>Hello <strong>GT</strong></p>'.
	paragraph := document children first.
	strong := paragraph children second.
	self assert: paragraph name equals: 'p'.
	self assert: paragraph children first text equals: 'Hello '.
	self assert: strong name equals: 'strong'.
	self assert: strong children first text equals: 'GT'
]

{ #category : 'tests' }
KGHtmlParserTest >> testParsesSelfClosingElement [
	| document image |
	document := KGHtmlParser parse: '<img src="picture.png"/>'.
	image := document children first.
	self assert: image name equals: 'img'.
	self assert: image children isEmpty.
	self assert: (image attributeAt: 'src') equals: 'picture.png'
]
