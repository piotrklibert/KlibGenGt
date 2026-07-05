"
Legacy non-HTML code block parsed from `--kod=<language> ... --/kod`.

- Slots
  - language <#String> accessing - Language tag from the opening marker.
  - code <#String> accessing - Raw code body between opening and closing markers.
- Public API
  - {{gtMethod:KGLegacyCodeBlock class>>#language:code:}} - Build a code block node.
  - {{gtMethod:KGLegacyCodeBlock>>#language}} - Answer the language tag.
  - {{gtMethod:KGLegacyCodeBlock>>#language:}} - Replace the language tag.
  - {{gtMethod:KGLegacyCodeBlock>>#code}} - Answer the raw code body.
  - {{gtMethod:KGLegacyCodeBlock>>#code:}} - Replace the raw code body.
  - {{gtMethod:KGLegacyCodeBlock>>#isCodeBlock}} - Answer true for legacy code blocks.
  - {{gtMethod:KGLegacyCodeBlock>>#writeHtmlOn:}} - Serialize the block as `<pre><code>`.
"
Class {
	#name : 'KGLegacyCodeBlock',
	#superclass : 'KGHtmlNode',
	#instVars : [
		'language',
		'code'
	],
	#category : 'KlibGenGt-Core-LegacyHtml',
	#package : 'KlibGenGt-Core'
}

{ #category : 'instance creation' }
KGLegacyCodeBlock class >> language: aString code: anotherString [
	<arg: #aString type: #String>
	<arg: #anotherString type: #String>
	<return: #KGLegacyCodeBlock>
	^ self new
		language: aString;
		code: anotherString;
		yourself
]

{ #category : 'accessing' }
KGLegacyCodeBlock >> code [
	<return: #String>
	^ code ifNil: [ '' ]
]

{ #category : 'accessing' }
KGLegacyCodeBlock >> code: aString [
	<arg: #aString type: #String>
	<return: #String>
	code := aString
]

{ #category : 'testing' }
KGLegacyCodeBlock >> isCodeBlock [
	<return: #Boolean>
	^ true
]

{ #category : 'accessing' }
KGLegacyCodeBlock >> language [
	<return: #String>
	^ language ifNil: [ '' ]
]

{ #category : 'accessing' }
KGLegacyCodeBlock >> language: aString [
	<arg: #aString type: #String>
	<return: #String>
	language := aString
]

{ #category : 'converting' }
KGLegacyCodeBlock >> writeHtmlOn: aStream [
	<arg: #aStream type: #Stream>
	<return: #Stream>
	aStream
		nextPutAll: '<pre><code class="language-';
		nextPutAll: (KGLegacyPostTransformer escapeAttribute: self language);
		nextPutAll: '">';
		nextPutAll: (KGLegacyPostTransformer escapeText: self code);
		nextPutAll: '</code></pre>'
]
