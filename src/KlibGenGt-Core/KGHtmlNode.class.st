"
Abstract base for the simplified legacy HTML AST.

- Slots
  - none
- Public API
  - {{gtMethod:KGHtmlNode>>#htmlString}} - Serialize this node and its descendants as HTML.
  - {{gtMethod:KGHtmlNode>>#writeHtmlOn:}} - Append serialized HTML to a stream; subclasses implement this.
  - {{gtMethod:KGHtmlNode>>#isElement}} - Answer whether this node is an HTML element.
  - {{gtMethod:KGHtmlNode>>#isText}} - Answer whether this node is text.
  - {{gtMethod:KGHtmlNode>>#isCodeBlock}} - Answer whether this node is a legacy code block.
"
Class {
	#name : 'KGHtmlNode',
	#superclass : 'Object',
	#category : 'KlibGenGt-Core-LegacyHtml',
	#package : 'KlibGenGt-Core',
	#tag : 'LegacyHtml'
}

{ #category : 'converting' }
KGHtmlNode >> htmlString [
	<return: #String>
	^ String streamContents: [ :stream | self writeHtmlOn: stream ]
]

{ #category : 'testing' }
KGHtmlNode >> isCodeBlock [
	<return: #Boolean>
	^ false
]

{ #category : 'testing' }
KGHtmlNode >> isElement [
	<return: #Boolean>
	^ false
]

{ #category : 'testing' }
KGHtmlNode >> isText [
	<return: #Boolean>
	^ false
]

{ #category : 'printing' }
KGHtmlNode >> printOn: aStream [
	aStream
		nextPutAll: self class name;
		nextPut: $(;
		nextPutAll: self htmlString;
		nextPut: $)
]

{ #category : 'converting' }
KGHtmlNode >> writeHtmlOn: aStream [
	<arg: #aStream type: #Stream>
	<return: #Object>
	self subclassResponsibility
]
