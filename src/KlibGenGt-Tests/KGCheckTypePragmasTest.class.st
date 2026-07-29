"
SUnit coverage for documentation type syntax validation.

- Slots
  - none
- Public API
  - none; test selectors are invoked by SUnit and document expected checker behavior.
"
Class {
	#name : 'KGCheckTypePragmasTest',
	#superclass : 'TestCase',
	#category : 'KlibGenGt-Tests',
	#package : 'KlibGenGt-Tests'
}

{ #category : 'tests' }
KGCheckTypePragmasTest >> testRejectsLegacyReturnsPragma [
	| results |
	self class
		compile: 'kgLegacyReturnsProbe
	<returns: #String>
	^ ''legacy'''
		classified: 'tests'.
	[
		results := KGCheckTypePragmas new inClass: self class.
		self assert: (results anySatisfy: [ :each |
			((each at: #source) includesSubstring: 'kgLegacyReturnsProbe')
				and: [ (each at: #valid) not ] ])
	] ensure: [ self class removeSelector: #kgLegacyReturnsProbe ]
]

{ #category : 'tests' }
KGCheckTypePragmasTest >> testInPackageIncludesExtensionMethods [
	| results |
	results := KGCheckTypePragmas new inPackage: 'KlibGenGt-Core'.
	self assert: (results anySatisfy: [ :each |
		(each at: #source) includesSubstring: 'Object>>#kgInfo' ])
]

{ #category : 'tests' }
KGCheckTypePragmasTest >> testProjectTypeAnnotationsAreValid [
	| results invalid description |
	results := KGCheckTypePragmas new inProject.
	invalid := results reject: [ :each | each at: #valid ].
	description := String streamContents: [ :stream |
		stream nextPutAll: 'Invalid documentation type annotations:'; lf.
		invalid do: [ :each |
			stream
				nextPutAll: (each at: #class) asString;
				nextPutAll: ' | ';
				nextPutAll: (each at: #source);
				nextPutAll: ' | ';
				nextPutAll: (each at: #type);
				nextPutAll: ' | ';
				nextPutAll: (each at: #message);
				lf ] ].
	self deny: results isEmpty.
	self assert: invalid isEmpty description: description
]

{ #category : 'tests' }
KGCheckTypePragmasTest >> testValidateTypeLiteral [
	| checker |
	checker := KGCheckTypePragmas new.
	self assert: (checker validateTypeLiteral: #String).
	self assert: (checker validateTypeLiteral: #(String?)).
	self assert: (checker validateTypeLiteral: #(OrderedCollection < (Number | String) >)).
	self assert: (checker validateTypeLiteral: #(String -> Boolean)).
	self deny: (checker validateTypeLiteral: #(String Boolean)).
	self deny: (checker validateTypeLiteral: #|)
]

{ #category : 'tests' }
KGCheckTypePragmasTest >> testValidateTypeString [
	| checker |
	checker := KGCheckTypePragmas new.
	self assert: (checker validateTypeString: '#String').
	self assert: (checker validateTypeString: '#(String?)').
	self assert: (checker validateTypeString: '#(Dictionary<String,Integer>)').
	self assert: (checker validateTypeString: '#(Array<(Array<String>)>)').
	self deny: (checker validateTypeString: 'String').
	self deny: (checker validateTypeString: '#(String Boolean)')
]
