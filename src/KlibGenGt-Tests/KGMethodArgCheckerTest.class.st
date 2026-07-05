"
SUnit coverage for the method argument checker example.

- Slots
  - none
- Public API
  - none; test selectors are invoked by SUnit and document expected checker behavior.
"
Class {
	#name : 'KGMethodArgCheckerTest',
	#superclass : 'TestCase',
	#category : 'KlibGenGt-Tests',
	#package : 'KlibGenGt-Tests'
}

{ #category : 'as yet unclassified' }
KGMethodArgCheckerTest >> testCandidateName [
	| checker name|
	checker := KGMethodArgChecker new.
	name := checker candidateTypeNameFor: 'aKlibGenGt'.
	self assert: name equals: 'KlibGenGt'.
]
