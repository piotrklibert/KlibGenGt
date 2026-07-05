"
SUnit coverage for project-level smoke checks and documentation helpers.

- Slots
  - none
- Public API
  - none; test selectors are invoked by SUnit and document expected project behavior.
"
Class {
	#name : 'KlibGenGtTest',
	#superclass : 'TestCase',
	#category : 'KlibGenGt-Tests',
	#package : 'KlibGenGt-Tests'
}

{ #category : 'tests' }
KlibGenGtTest >> testClassHierarchyClassesIncludeProjectClassesAndRoots [
	| classes |
	classes := KlibGenGt classHierarchyClasses.
	self assert: (classes includes: KlibGenGt).
	self assert: (classes includes: KGHtmlParser).
	self assert: (classes includes: KGLegacyPostTransformerTest).
	self assert: (classes includes: Object).
	self assert: (classes includes: PP2CompositeNode).
	self assert: (classes includes: TestCase)
]

{ #category : 'tests' }
KlibGenGtTest >> testClassHierarchyCommentEmbedsMondrianExample [
	self assert: (KlibGenGt comment includesSubstring: '{{gtExample:KlibGenGt class>>#classHierarchyMondrian')
]

{ #category : 'tests' }
KlibGenGtTest >> testClassHierarchyMondrianBuilds [
	| mondrian |
	mondrian := KlibGenGt classHierarchyMondrian.
	self assert: mondrian class equals: GtMondrian.
	self
		assert: mondrian topStep root graph nodeChildren size
		equals: KlibGenGt classHierarchyClasses size
]

{ #category : 'tests' }
KlibGenGtTest >> testProjectName [
    self assert: KlibGenGt projectName equals: 'KlibGenGt'
]

{ #category : 'tests' }
KlibGenGtTest >> testSampleGreeting [
    self assert: KlibGenGt sampleGreeting equals: 'Hello from KlibGenGt'
]
