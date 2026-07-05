Class {
	#name : 'KGClassExporter',
	#superclass : 'Object',
	#category : 'KlibGenGt-Examples',
	#package : 'KlibGenGt-Examples'
}

{ #category : 'as yet unclassified' }
KGClassExporter class >> exportClass: aClass [
	| stream |
	stream := WriteStream on: String new.
	self exportClass: aClass on: stream.
	^ stream contents.
]

{ #category : 'as yet unclassified' }
KGClassExporter class >> exportClass: aClass on: aStream [
	TonelWriter new exportClass: aClass on: aStream.
]
