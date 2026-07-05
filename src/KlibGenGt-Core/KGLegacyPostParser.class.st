"
Legacy post parser that extends {{gtClass:KGHtmlParser}} with non-HTML constructs found in old posts.

- Slots
  - legacyCodeBlock <#PP2Node> grammar - Grammar production for `--kod=<language> ... --/kod` blocks.
- Public API
  - {{gtMethod:KGHtmlParser class>>#parse:}} - Inherited parser entrypoint; returns a {{gtClass:KGHtmlDocument}} containing HTML and legacy code block nodes.
"
Class {
	#name : 'KGLegacyPostParser',
	#superclass : 'KGHtmlParser',
	#instVars : [
		'legacyCodeBlock'
	],
	#category : 'KlibGenGt-Core-LegacyHtml',
	#package : 'KlibGenGt-Core'
}

{ #category : 'grammar' }
KGLegacyPostParser >> legacyCodeBlock [
	<return: #PP2Node>
	^ '--kod=' asPParser
		, #newline asPParser negate plus flatten
		, #newline asPParser
		, '--/kod' asPParser negate star flatten
		, '--/kod' asPParser
		==> [ :node |
			KGLegacyCodeBlock
				language: node second
				code: node fourth ]
]

{ #category : 'accessing' }
KGLegacyPostParser >> node [
	<return: #PP2Node>
	^ legacyCodeBlock / selfClosingElement / element / text
]

{ #category : 'grammar' }
KGLegacyPostParser >> text [
	<return: #PP2Node>
	^ ('--kod=' asPParser / $< asPParser) negate plus flatten
		==> [ :value | KGHtmlText text: value ]
]
