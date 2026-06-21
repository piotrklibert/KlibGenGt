Class {
	#name : 'KlibGenGt',
	#superclass : 'Object',
	#category : 'KlibGenGt-Core',
	#package : 'KlibGenGt-Core'
}

{ #category : 'accessing' }
KlibGenGt class >> projectName [
    ^ 'KlibGenGt'
]

{ #category : 'accessing' }
KlibGenGt class >> sampleGreeting [
    ^ 'Hello from ', self projectName
]
