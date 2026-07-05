"
Scratchpad examples used to exercise project dependencies from GT.

- Slots
  - none
- Public API
  - {{gtMethod:KGScratchPadScripts>>#example1}} - Build a nested dictionary from the GT book table of contents.
  - {{gtMethod:KGScratchPadScripts>>#example2}} - Run the method argument checker example.
  - {{gtMethod:KGScratchPadScripts>>#sampleGreeting}} - Return the project smoke-test greeting.
"
Class {
	#name : 'KGScratchPadScripts',
	#superclass : 'Object',
	#category : 'KlibGenGt-Examples',
	#package : 'KlibGenGt-Examples'
}

{ #category : 'examples' }
KGScratchPadScripts >> example1 [
	<gtExample>
	<return: #Dictionary>
	| database tocPage extractChildren extractTitle normalizeLinkTitle |
	database := LeStorageExamples new gtBook.
	tocPage := database tableOfContents.

	normalizeLinkTitle := [ :aString | 
		| trimmed |
		trimmed := aString trimBoth.
		((trimmed beginsWith: '[[') and: [ trimmed endsWith: ']]' ])
			ifTrue: [ trimmed copyFrom: 3 to: trimmed size - 2 ]
			ifFalse: [ trimmed ] ].

	extractTitle := [ :aSnippet | 
		(aSnippet respondsTo: #string)
			ifTrue: [ normalizeLinkTitle value: aSnippet string ]
			ifFalse: [ aSnippet printString ] ].

	extractChildren := [ :aSnippet | 
		| result |
		result := Dictionary new.
		(aSnippet children respondsTo: #do:)
			ifTrue: [ aSnippet children
					do: [ :eachChild | 
						result
							at: (extractTitle value: eachChild)
							put: (extractChildren value: eachChild) ] ].
		result ].

	^ Dictionary new
		at: tocPage title put: (extractChildren value: tocPage children);
		yourself
]

{ #category : 'examples' }
KGScratchPadScripts >> example2 [
	<gtExample>
	<return: #Dictionary>
	^KGMethodArgChecker new run.
]

{ #category : 'examples' }
KGScratchPadScripts >> sampleGreeting [
    <gtExample>
	<return: #String>

    ^ KlibGenGt sampleGreeting
]
