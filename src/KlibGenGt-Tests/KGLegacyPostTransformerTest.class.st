"
SUnit coverage for legacy post transformation rules.

- Slots
  - none
- Public API
  - none; test selectors are invoked by SUnit and document expected transformer behavior.
"
Class {
	#name : 'KGLegacyPostTransformerTest',
	#superclass : 'TestCase',
	#category : 'KlibGenGt-Tests-LegacyHtml',
	#package : 'KlibGenGt-Tests',
	#tag : 'LegacyHtml'
}

{ #category : 'tests' }
KGLegacyPostTransformerTest >> testPrefixesH3Id [
	| html |
	html := KGLegacyPostTransformer
		transform: '<h3 id="intro">Intro</h3>'
		fname: 'demo'
		link: 'demo'.
	self assert: html equals: '<h3 class="sub" id="demo-intro">Intro</h3>'
]

{ #category : 'tests' }
KGLegacyPostTransformerTest >> testTransformsMyImage [
	| html |
	html := KGLegacyPostTransformer
		transform: '<my-img src="pic.png" alt="Picture"></my-img>'
		fname: 'demo'
		link: 'demo'.
	self
		assert: html
		equals: '<div style="text-align: center" class="post-image"><a title="click to enlarge" href="pic.png"><img src="pic.png" alt="Picture"></a></div>'
]

{ #category : 'tests' }
KGLegacyPostTransformerTest >> testTransformsNoticeAndNote [
	| html |
	html := KGLegacyPostTransformer
		transform: '<notice><note>Read this</note></notice>'
		fname: 'demo'
		link: 'demo'.
	self
		assert: html
		equals: '<div class="alert alert-info"><div class="note"><strong>NOTE: </strong>Read this</div></div>'
]

{ #category : 'tests' }
KGLegacyPostTransformerTest >> testTransformsSubHeader [
	| html |
	html := KGLegacyPostTransformer
		transform: '<sub-header>Details</sub-header>'
		fname: 'demo'
		link: 'demo'.
	self assert: html equals: '<h3 class="sub">Details</h3>'
]
