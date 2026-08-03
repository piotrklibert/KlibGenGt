"
Smalltalk implementation of the legacy post HTML rewrite rules.

- Slots
  - context <#KGLegacyPostTransformContext> accessing - Parameters used while generating URLs, anchors, and metadata.
- Public API
  - {{gtMethod:KGLegacyPostTransformer class>>#transform:fname:link:}} - Transform a legacy post fragment using default publication date.
  - {{gtMethod:KGLegacyPostTransformer class>>#transform:fname:link:pubdate:}} - Transform a legacy post fragment with explicit parameters.
  - {{gtMethod:KGLegacyPostTransformer class>>#escapeText:}} - Escape text for safe HTML serialization.
  - {{gtMethod:KGLegacyPostTransformer class>>#escapeAttribute:}} - Escape an attribute value for safe HTML serialization.
  - {{gtMethod:KGLegacyPostTransformer>>#transformDocument:}} - Transform a parsed document into a rewritten document.
"
Class {
	#name : 'KGLegacyPostTransformer',
	#superclass : 'Object',
	#instVars : [
		'context'
	],
	#category : 'KlibGenGt-Core-LegacyHtml',
	#package : 'KlibGenGt-Core',
	#tag : 'LegacyHtml'
}

{ #category : 'escaping' }
KGLegacyPostTransformer class >> escapeAttribute: aString [
	<arg: #aString type: #String>
	<return: #String>
	^ ((((aString ifNil: [ '' ])
		copyReplaceAll: '&' with: '&amp;')
		copyReplaceAll: '"' with: '&quot;')
		copyReplaceAll: '<' with: '&lt;')
		copyReplaceAll: '>' with: '&gt;'
]

{ #category : 'escaping' }
KGLegacyPostTransformer class >> escapeText: aString [
	<arg: #aString type: #String>
	<return: #String>
	^ (((aString ifNil: [ '' ])
		copyReplaceAll: '&' with: '&amp;')
		copyReplaceAll: '<' with: '&lt;')
		copyReplaceAll: '>' with: '&gt;'
]

{ #category : 'transforming' }
KGLegacyPostTransformer class >> transform: htmlText fname: fname link: link [
	<arg: #htmlText type: #String>
	<arg: #fname type: #String>
	<arg: #link type: #String>
	<return: #String>
	^ self transform: htmlText fname: fname link: link pubdate: ''
]

{ #category : 'transforming' }
KGLegacyPostTransformer class >> transform: htmlText fname: fname link: link pubdate: pubdate [
	<arg: #htmlText type: #String>
	<arg: #fname type: #String>
	<arg: #link type: #String>
	<arg: #pubdate type: #String>
	<return: #String>
	| document transformed |
	document := KGLegacyPostParser parse: htmlText.
	transformed := self new
		context: (KGLegacyPostTransformContext fname: fname link: link pubdate: pubdate);
		transformDocument: document.
	^ transformed htmlString
]

{ #category : 'building' }
KGLegacyPostTransformer >> attributes: pairs [
	<arg: #pairs type: #Array>
	<return: #OrderedDictionary>
	| dictionary |
	dictionary := OrderedDictionary new.
	pairs pairsDo: [ :key :value | dictionary at: key put: value ].
	^ dictionary
]

{ #category : 'accessing' }
KGLegacyPostTransformer >> context [
	<return: #KGLegacyPostTransformContext>
	^ context
]

{ #category : 'accessing' }
KGLegacyPostTransformer >> context: anObject [
	<arg: #anObject type: #KGLegacyPostTransformContext>
	<return: #KGLegacyPostTransformContext>
	context := anObject
]

{ #category : 'building' }
KGLegacyPostTransformer >> elementNamed: name attributes: attributes children: children [
	<arg: #name type: #String>
	<arg: #attributes type: #OrderedDictionary>
	<arg: #children type: #(Collection | Array)>
	<return: #KGHtmlElement>
	^ KGHtmlElement name: name attributes: attributes children: children
]

{ #category : 'building' }
KGLegacyPostTransformer >> emptyAttributes [
	<return: #OrderedDictionary>
	^ OrderedDictionary new
]

{ #category : 'building' }
KGLegacyPostTransformer >> firstChildElementNamed: aString in: anElement [
	<arg: #aString type: #String>
	<arg: #anElement type: #KGHtmlElement>
	<return: #(KGHtmlElement?)>
	^ anElement children
		detect: [ :each | each isElement and: [ each name = aString ] ]
		ifNone: [ nil ]
]

{ #category : 'building' }
KGLegacyPostTransformer >> permalinkAnchor [
	<return: #KGHtmlElement>
	^ self
		elementNamed: 'a'
		attributes: (self attributes: {
			'href'. '#' , self context link.
			'class'. 'robaczek'.
			'title'. 'Link to this place on current page' })
		children: { self text: '
          ¶
        ' }
]

{ #category : 'building' }
KGLegacyPostTransformer >> text: aString [
	<arg: #aString type: #String>
	<return: #KGHtmlText>
	^ KGHtmlText text: aString
]

{ #category : 'transforming' }
KGLegacyPostTransformer >> transformBQ: anElement [
	<arg: #anElement type: #KGHtmlElement>
	<return: #KGHtmlElement>
	^ self
		elementNamed: 'div'
		attributes: self emptyAttributes
		children: {
			self
				elementNamed: 'blockquote'
				attributes: (self attributes: #( 'class' 'no-quote' ))
				children: {
					self
						elementNamed: 'code'
						attributes: self emptyAttributes
						children: (self transformNodes: anElement children) } }
]

{ #category : 'transforming' }
KGLegacyPostTransformer >> transformDocument: aDocument [
	<arg: #aDocument type: #KGHtmlDocument>
	<return: #KGHtmlDocument>
	^ KGHtmlDocument children: (self transformNodes: aDocument children)
]

{ #category : 'transforming' }
KGLegacyPostTransformer >> transformElement: anElement [
	<arg: #anElement type: #KGHtmlElement>
	<return: #KGHtmlNode>
	(anElement name = 'note' and: [ anElement hasClassIncluding: 'outdated' ])
		ifTrue: [ ^ self transformOutdatedNote: anElement ].
	anElement name = 'sub-header' ifTrue: [ ^ self transformSubHeader: anElement ].
	anElement name = 'h3' ifTrue: [ ^ self transformH3: anElement ].
	anElement name = 'my-header' ifTrue: [ ^ self transformMyHeader: anElement ].
	anElement name = 'header' ifTrue: [ ^ self transformLegacyHeader: anElement ].
	anElement name = 'my-img' ifTrue: [ ^ self transformMyImg: anElement ].
	anElement name = 'bq' ifTrue: [ ^ self transformBQ: anElement ].
	anElement name = 'notice' ifTrue: [ ^ self transformNotice: anElement ].
	anElement name = 'note' ifTrue: [ ^ self transformNote: anElement ].
	^ self
		elementNamed: anElement name
		attributes: anElement attributes copy
		children: (self transformNodes: anElement children)
]

{ #category : 'transforming' }
KGLegacyPostTransformer >> transformH3: anElement [
	<arg: #anElement type: #KGHtmlElement>
	<return: #KGHtmlElement>
	| attributes |
	attributes := self attributes: #( 'class' 'sub' ).
	(anElement attributes includesKey: 'id')
		ifTrue: [
			attributes
				at: 'id'
				put: self context fname , '-' , (anElement attributeAt: 'id') ].
	anElement attributes keysAndValuesDo: [ :key :value |
		key = 'id' ifFalse: [ attributes at: key put: value ] ].
	^ self
		elementNamed: 'h3'
		attributes: attributes
		children: (self transformNodes: anElement children)
]

{ #category : 'transforming' }
KGLegacyPostTransformer >> transformLegacyHeader: anElement [
	<arg: #anElement type: #KGHtmlElement>
	<return: #KGHtmlElement>
	| h1 paragraph time title |
	h1 := self firstChildElementNamed: 'h1' in: anElement.
	paragraph := self firstChildElementNamed: 'p' in: anElement.
	time := paragraph
		ifNil: [ nil ]
		ifNotNil: [ self firstChildElementNamed: 'time' in: paragraph ].
	title := h1 ifNil: [ '' ] ifNotNil: [ h1 textContent ].
	^ self
		elementNamed: 'header'
		attributes: self emptyAttributes
		children: {
			self
				elementNamed: 'h1'
				attributes: (self attributes: #( 'class' 'entry-title' ))
				children: {
					self
						elementNamed: 'a'
						attributes: (self attributes: {
							'class'. 'title-link'.
							'id'. self context fname.
							'href'. 'posts/' , self context link , '.html'.
							'title'. 'Read on separate page' })
						children: { self text: title }.
					self permalinkAnchor }.
			self
				elementNamed: 'p'
				attributes: (self attributes: #( 'class' 'meta' ))
				children: {
					self
						elementNamed: 'time'
						attributes: self emptyAttributes
						children: { self text: (time ifNil: [ '' ] ifNotNil: [ time textContent ]) } } }
]

{ #category : 'transforming' }
KGLegacyPostTransformer >> transformMyHeader: anElement [
	<arg: #anElement type: #KGHtmlElement>
	<return: #KGHtmlElement>
	| time subtitle children headerChildren titleChildren |
	time := self firstChildElementNamed: 'time' in: anElement.
	subtitle := self firstChildElementNamed: 'sub-title' in: anElement.
	titleChildren := anElement children select: [ :each |
		each isText or: [ each isElement and: [ each name = 'l' ] ] ].
	headerChildren := OrderedCollection new.
	headerChildren add: (self
		elementNamed: 'h1'
		attributes: (self attributes: #( 'class' 'entry-title' ))
		children: {
			self
				elementNamed: 'a'
				attributes: (self attributes: {
					'class'. 'title-link'.
					'id'. self context fname.
					'href'. '/posts/' , self context link , '.html'.
					'title'. 'Read on separate page' })
				children: (self transformNodes: titleChildren).
			self permalinkAnchor }).
	(subtitle notNil and: [ subtitle children notEmpty ])
		ifTrue: [
			headerChildren add: (self
				elementNamed: 'h3'
				attributes: (self attributes: #( 'class' 'subtitle' ))
				children: (self transformNodes: subtitle children)) ].
	children := {
		self text: '
        Last updated on: '.
		self
			elementNamed: 'time'
			attributes: self emptyAttributes
			children: { self text: (time ifNil: [ '' ] ifNotNil: [ time textContent ]) } }.
	headerChildren add: (self
		elementNamed: 'p'
		attributes: (self attributes: #( 'class' 'meta' ))
		children: children).
	^ self
		elementNamed: 'header'
		attributes: self emptyAttributes
		children: headerChildren
]

{ #category : 'transforming' }
KGLegacyPostTransformer >> transformMyImg: anElement [
	<arg: #anElement type: #KGHtmlElement>
	<return: #KGHtmlElement>
	| src imageAttributes |
	src := anElement attributeAt: 'src' ifAbsent: [ '' ].
	imageAttributes := anElement attributes copy.
	imageAttributes at: 'src' put: src.
	^ self
		elementNamed: 'div'
		attributes: (self attributes: #( 'style' 'text-align: center' 'class' 'post-image' ))
		children: {
			self
				elementNamed: 'a'
				attributes: (self attributes: {
					'title'. 'click to enlarge'.
					'href'. src })
				children: {
					self
						elementNamed: 'img'
						attributes: imageAttributes
						children: #() } }
]

{ #category : 'transforming' }
KGLegacyPostTransformer >> transformNode: aNode [
	<arg: #aNode type: #KGHtmlNode>
	<return: #KGHtmlNode>
	aNode isText ifTrue: [ ^ KGHtmlText text: aNode text ].
	aNode isElement ifTrue: [ ^ self transformElement: aNode ].
	aNode isCodeBlock ifTrue: [ ^ aNode ].
	^ aNode
]

{ #category : 'transforming' }
KGLegacyPostTransformer >> transformNodes: nodes [
	<arg: #nodes type: #(Collection | Array)>
	<return: #Collection>
	^ nodes collect: [ :each | self transformNode: each ]
]

{ #category : 'transforming' }
KGLegacyPostTransformer >> transformNote: anElement [
	<arg: #anElement type: #KGHtmlElement>
	<return: #KGHtmlElement>
	^ self
		elementNamed: 'div'
		attributes: (self attributes: #( 'class' 'note' ))
		children: ({ self
			elementNamed: 'strong'
			attributes: self emptyAttributes
			children: { self text: 'NOTE: ' } } , (self transformNodes: anElement children))
]

{ #category : 'transforming' }
KGLegacyPostTransformer >> transformNotice: anElement [
	<arg: #anElement type: #KGHtmlElement>
	<return: #KGHtmlElement>
	^ self
		elementNamed: 'div'
		attributes: (self attributes: #( 'class' 'alert alert-info' ))
		children: (self transformNodes: anElement children)
]

{ #category : 'transforming' }
KGLegacyPostTransformer >> transformOutdatedNote: anElement [
	<arg: #anElement type: #KGHtmlElement>
	<return: #KGHtmlElement>
	^ self
		elementNamed: 'div'
		attributes: (self attributes: { 'class'. (anElement attributeAt: 'class' ifAbsent: [ '' ]) })
		children: {
			self
				elementNamed: 'div'
				attributes: (self attributes: #( 'class' 'outdated' ))
				children: ({ self
					elementNamed: 'strong'
					attributes: self emptyAttributes
					children: { self text: 'NOTE:' } } , (self transformNodes: anElement children)) }
]

{ #category : 'transforming' }
KGLegacyPostTransformer >> transformSubHeader: anElement [
	<arg: #anElement type: #KGHtmlElement>
	<return: #KGHtmlElement>
	| attributes |
	attributes := self attributes: #( 'class' 'sub' ).
	anElement attributes keysAndValuesDo: [ :key :value | attributes at: key put: value ].
	^ self
		elementNamed: 'h3'
		attributes: attributes
		children: (self transformNodes: anElement children)
]
