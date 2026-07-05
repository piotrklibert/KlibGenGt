"
Text node in the simplified legacy HTML AST.

- Slots
  - text <#String> accessing - Literal text captured between HTML or legacy constructs.
- Public API
  - {{gtMethod:KGHtmlText class>>#text:}} - Build a text node.
  - {{gtMethod:KGHtmlText>>#text}} - Answer the literal text.
  - {{gtMethod:KGHtmlText>>#text:}} - Replace the literal text.
  - {{gtMethod:KGHtmlText>>#isText}} - Answer true for text nodes.
  - {{gtMethod:KGHtmlText>>#writeHtmlOn:}} - Serialize escaped text to a stream.
"
Class {
	#name : 'KGHtmlText',
	#superclass : 'KGHtmlNode',
	#instVars : [
		'text'
	],
	#category : 'KlibGenGt-Core-LegacyHtml',
	#package : 'KlibGenGt-Core'
}

{ #category : 'instance creation' }
KGHtmlText class >> text: aString [
	<arg: #aString type: #String>
	<return: #KGHtmlText>
	^ self new
		text: aString;
		yourself
]

{ #category : 'testing' }
KGHtmlText >> isText [
	<return: #Boolean>
	^ true
]

{ #category : 'accessing' }
KGHtmlText >> text [
	<return: #String>
	^ text ifNil: [ '' ]
]

{ #category : 'accessing' }
KGHtmlText >> text: aString [
	<arg: #aString type: #String>
	<return: #String>
	text := aString
]

{ #category : 'converting' }
KGHtmlText >> writeHtmlOn: aStream [
	<arg: #aStream type: #Stream>
	<return: #Stream>
	aStream nextPutAll: (KGLegacyPostTransformer escapeText: self text)
]
