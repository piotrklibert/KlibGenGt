"
Root node for parsed legacy HTML fragments.

- Slots
  - children <#(Array<KGHtmlNode>)> accessing - Top-level parsed nodes in source order.
- Public API
  - {{gtMethod:KGHtmlDocument class>>#children:}} - Build a document from top-level nodes.
  - {{gtMethod:KGHtmlDocument>>#children}} - Answer the top-level nodes.
  - {{gtMethod:KGHtmlDocument>>#children:}} - Replace the top-level nodes.
  - {{gtMethod:KGHtmlDocument>>#writeHtmlOn:}} - Serialize all children to a stream.
"
Class {
	#name : 'KGHtmlDocument',
	#superclass : 'KGHtmlNode',
	#instVars : [
		'children'
	],
	#category : 'KlibGenGt-Core-LegacyHtml',
	#package : 'KlibGenGt-Core'
}

{ #category : 'instance creation' }
KGHtmlDocument class >> children: aCollection [
	<arg: #aCollection type: #(Collection | Array)>
	<return: #KGHtmlDocument>
	^ self new
		children: aCollection;
		yourself
]

{ #category : 'accessing' }
KGHtmlDocument >> children [
	<return: #Array>
	^ children ifNil: [ #() ]
]

{ #category : 'accessing' }
KGHtmlDocument >> children: aCollection [
	<arg: #aCollection type: #(Collection | Array)>
	<return: #Array>
	children := aCollection asArray
]

{ #category : 'converting' }
KGHtmlDocument >> writeHtmlOn: aStream [
	<arg: #aStream type: #Stream>
	<return: #Collection>
	self children do: [ :each | each writeHtmlOn: aStream ]
]
