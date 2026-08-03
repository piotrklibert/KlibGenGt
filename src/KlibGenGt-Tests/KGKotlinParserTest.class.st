"
SUnit coverage for the Kotlin sample parser and declaration extractor.

- Slots
  - none
- Public API
  - none; test selectors are invoked by SUnit and document expected parser behavior.
"
Class {
	#name : 'KGKotlinParserTest',
	#superclass : 'TestCase',
	#category : 'KlibGenGt-Tests-Kotlin',
	#package : 'KlibGenGt-Tests',
	#tag : 'Kotlin'
}

{ #category : 'private' }
KGKotlinParserTest >> fixture [
	<return: #Dictionary>
	^ NeoJSONReader fromString: self fixtureFile contents
]

{ #category : 'private' }
KGKotlinParserTest >> fixtureFile [
	<return: #FileReference>
	^ self samplesDirectory / 'defined-types.fixture.json'
]

{ #category : 'private' }
KGKotlinParserTest >> samplesDirectory [
	<return: #FileReference>
	^ FileLocator workingDirectory / 'data' / 'kotlin-samples'
]

{ #category : 'tests' }
KGKotlinParserTest >> testParsesExtensionFunction [
	| file function |
	file := KGKotlinParser parse: 'package demo

fun String.slugify(limit: Int = 10): String = this
'.
	function := file declarations first.
	self assert: function name equals: 'slugify'.
	self assert: function receiver equals: 'String'.
	self assert: function parameters first name equals: 'limit'.
	self assert: function parameters first type equals: 'Int'.
	self assert: function returnType equals: 'String'
]

{ #category : 'tests' }
KGKotlinParserTest >> testParsesImportAliasAndWildcard [
	| file |
	file := KGKotlinParser parse: 'package demo

import kotlin.collections.* as Collections
'.
	self assert: file packageName equals: 'demo'.
	self assert: file imports first path equals: 'kotlin.collections'.
	self assert: file imports first wildcard.
	self assert: file imports first alias equals: 'Collections'
]

{ #category : 'tests' }
KGKotlinParserTest >> testParsesNestedTypeDeclarations [
	| file root |
	file := KGKotlinParser parse: '@Serializable
sealed interface Root {
    @SerialName("leaf")
    data class Leaf(val value: String) : Root
}
'.
	root := file declarations first.
	self assert: root kind equals: 'interface'.
	self assert: root annotations equals: #( 'Serializable' ).
	self assert: root declarations first name equals: 'Leaf'.
	self assert: root declarations first supertypes equals: #( 'Root' )
]

{ #category : 'tests' }
KGKotlinParserTest >> testSampleFilesMatchFixture [
	| expected |
	expected := self fixture.
	expected keysAndValuesDo: [ :fileName :expectedDictionary |
		| actual |
		actual := (KGKotlinParser parseFile: self samplesDirectory / fileName)
			asFixtureDictionary.
		self assert: actual equals: expectedDictionary ]
]
