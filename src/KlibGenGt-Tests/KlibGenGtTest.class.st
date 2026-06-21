Class {
	#name : 'KlibGenGtTest',
	#superclass : 'TestCase',
	#category : 'KlibGenGt-Tests',
	#package : 'KlibGenGt-Tests'
}

{ #category : 'tests' }
KlibGenGtTest >> testProjectName [
    self assert: KlibGenGt projectName equals: 'KlibGenGt'
]

{ #category : 'tests' }
KlibGenGtTest >> testSampleGreeting [
    self assert: KlibGenGt sampleGreeting equals: 'Hello from KlibGenGt'
]
