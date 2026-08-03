"
Value object carrying legacy post transformation parameters.

- Slots
  - fname <#String> accessing - Stable post identifier used for generated anchor IDs.
  - link <#String> accessing - Post link slug used for generated URLs and permalinks.
  - pubdate <#String> accessing - Publication date parameter kept for parity with the legacy transform.
- Public API
  - {{gtMethod:KGLegacyPostTransformContext class>>#fname:link:pubdate:}} - Build a transform context.
  - {{gtMethod:KGLegacyPostTransformContext>>#fname}} - Answer the post identifier.
  - {{gtMethod:KGLegacyPostTransformContext>>#fname:}} - Replace the post identifier.
  - {{gtMethod:KGLegacyPostTransformContext>>#link}} - Answer the link slug, defaulting to `fname`.
  - {{gtMethod:KGLegacyPostTransformContext>>#link:}} - Replace the link slug.
  - {{gtMethod:KGLegacyPostTransformContext>>#pubdate}} - Answer the publication date parameter.
  - {{gtMethod:KGLegacyPostTransformContext>>#pubdate:}} - Replace the publication date parameter.
"
Class {
	#name : 'KGLegacyPostTransformContext',
	#superclass : 'Object',
	#instVars : [
		'fname',
		'link',
		'pubdate'
	],
	#category : 'KlibGenGt-Core-LegacyHtml',
	#package : 'KlibGenGt-Core',
	#tag : 'LegacyHtml'
}

{ #category : 'instance creation' }
KGLegacyPostTransformContext class >> fname: aString link: anotherString pubdate: thirdString [
	<arg: #aString type: #String>
	<arg: #anotherString type: #String>
	<arg: #thirdString type: #String>
	<return: #KGLegacyPostTransformContext>
	^ self new
		fname: aString;
		link: anotherString;
		pubdate: thirdString;
		yourself
]

{ #category : 'accessing' }
KGLegacyPostTransformContext >> fname [
	<return: #String>
	^ fname ifNil: [ '' ]
]

{ #category : 'accessing' }
KGLegacyPostTransformContext >> fname: aString [
	<arg: #aString type: #String>
	<return: #String>
	fname := aString
]

{ #category : 'accessing' }
KGLegacyPostTransformContext >> link [
	<return: #String>
	^ link ifNil: [ self fname ]
]

{ #category : 'accessing' }
KGLegacyPostTransformContext >> link: aString [
	<arg: #aString type: #String>
	<return: #String>
	link := aString
]

{ #category : 'accessing' }
KGLegacyPostTransformContext >> pubdate [
	<return: #String>
	^ pubdate ifNil: [ '' ]
]

{ #category : 'accessing' }
KGLegacyPostTransformContext >> pubdate: aString [
	<arg: #aString type: #String>
	<return: #String>
	pubdate := aString
]
