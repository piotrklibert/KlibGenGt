"
HTML element node in the simplified legacy HTML AST.

- Slots
  - name <#String> accessing - Element tag name.
  - attributes <#(OrderedDictionary<String,String>)> accessing - Ordered attribute names and values.
  - children <#(Array<KGHtmlNode>)> accessing - Child nodes in source order.
- Public API
  - {{gtMethod:KGHtmlElement class>>#name:attributes:children:}} - Build an element node.
  - {{gtMethod:KGHtmlElement class>>#voidElementNames}} - Answer tag names serialized without an explicit closing tag when empty.
  - {{gtMethod:KGHtmlElement>>#name}} - Answer the tag name.
  - {{gtMethod:KGHtmlElement>>#name:}} - Replace the tag name.
  - {{gtMethod:KGHtmlElement>>#attributes}} - Answer the ordered attributes.
  - {{gtMethod:KGHtmlElement>>#attributes:}} - Replace the ordered attributes.
  - {{gtMethod:KGHtmlElement>>#attributeAt:}} - Answer a required attribute value.
  - {{gtMethod:KGHtmlElement>>#attributeAt:ifAbsent:}} - Answer an attribute value or evaluate a fallback block.
  - {{gtMethod:KGHtmlElement>>#children}} - Answer child nodes.
  - {{gtMethod:KGHtmlElement>>#children:}} - Replace child nodes.
  - {{gtMethod:KGHtmlElement>>#hasClassIncluding:}} - Check whether the `class` attribute contains a substring.
  - {{gtMethod:KGHtmlElement>>#textContent}} - Answer concatenated descendant text.
  - {{gtMethod:KGHtmlElement>>#writeHtmlOn:}} - Serialize the element and descendants to a stream.
"
Class {
	#name : 'KGHtmlElement',
	#superclass : 'KGHtmlNode',
	#instVars : [
		'name',
		'attributes',
		'children'
	],
	#category : 'KlibGenGt-Core-LegacyHtml',
	#package : 'KlibGenGt-Core'
}

{ #category : 'instance creation' }
KGHtmlElement class >> name: aString attributes: anOrderedDictionary children: aCollection [
	<arg: #aString type: #String>
	<arg: #anOrderedDictionary type: #OrderedDictionary>
	<arg: #aCollection type: #(Collection | Array)>
	<return: #KGHtmlElement>
	^ self new
		name: aString;
		attributes: anOrderedDictionary;
		children: aCollection;
		yourself
]

{ #category : 'utilities' }
KGHtmlElement class >> voidElementNames [
	<return: #Array>
	^ #( 'area' 'base' 'br' 'col' 'embed' 'hr' 'img' 'input' 'link' 'meta' 'param' 'source' 'track' 'wbr' )
]

{ #category : 'accessing' }
KGHtmlElement >> attributeAt: aString [
	<arg: #aString type: #String>
	<return: #String>
	^ self attributes at: aString
]

{ #category : 'accessing' }
KGHtmlElement >> attributeAt: aString ifAbsent: aBlock [
	<arg: #aString type: #String>
	<arg: #aBlock type: #BlockClosure>
	<return: #Object>
	^ self attributes at: aString ifAbsent: aBlock
]

{ #category : 'accessing' }
KGHtmlElement >> attributes [
	<return: #OrderedDictionary>
	^ attributes ifNil: [ OrderedDictionary new ]
]

{ #category : 'accessing' }
KGHtmlElement >> attributes: anOrderedDictionary [
	<arg: #anOrderedDictionary type: #OrderedDictionary>
	<return: #OrderedDictionary>
	attributes := anOrderedDictionary
]

{ #category : 'accessing' }
KGHtmlElement >> children [
	<return: #Array>
	^ children ifNil: [ #() ]
]

{ #category : 'accessing' }
KGHtmlElement >> children: aCollection [
	<arg: #aCollection type: #(Collection | Array)>
	<return: #Array>
	children := aCollection asArray
]

{ #category : 'testing' }
KGHtmlElement >> hasClassIncluding: aString [
	<arg: #aString type: #String>
	<return: #Boolean>
	^ (self attributeAt: 'class' ifAbsent: [ '' ]) includesSubstring: aString
]

{ #category : 'testing' }
KGHtmlElement >> isElement [
	<return: #Boolean>
	^ true
]

{ #category : 'accessing' }
KGHtmlElement >> name [
	<return: #String>
	^ name
]

{ #category : 'accessing' }
KGHtmlElement >> name: aString [
	<arg: #aString type: #String>
	<return: #String>
	name := aString
]

{ #category : 'converting' }
KGHtmlElement >> textContent [
	<return: #String>
	^ String streamContents: [ :stream |
		self children do: [ :each |
			each isText
				ifTrue: [ stream nextPutAll: each text ]
				ifFalse: [
					each isElement ifTrue: [
						stream nextPutAll: each textContent ] ] ] ]
]

{ #category : 'converting' }
KGHtmlElement >> writeHtmlOn: aStream [
	<arg: #aStream type: #Stream>
	<return: #Stream>
	aStream
		nextPut: $<;
		nextPutAll: self name.
	self attributes keysAndValuesDo: [ :key :value |
		aStream
			space;
			nextPutAll: key;
			nextPutAll: '="';
			nextPutAll: (KGLegacyPostTransformer escapeAttribute: value);
			nextPut: $" ].
	aStream nextPut: $>.
	((self children isEmpty) and: [
		self class voidElementNames includes: self name asLowercase ])
		ifTrue: [ ^ self ].
	self children do: [ :each | each writeHtmlOn: aStream ].
	aStream
		nextPutAll: '</';
		nextPutAll: self name;
		nextPut: $>
]
