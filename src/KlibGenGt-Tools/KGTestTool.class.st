"
Run project SUnit tests and retain structured diagnostics at exception signal time.

- Slots
  - none
- Public API
  - {{gtMethod:KGTestTool>>#run:}}
    Run the class and optional selector named by an image-tool request.
  - {{gtMethod:KGTestTool>>#runAllProjectTests}}
    Run every project test for build contracts and return a JSON-compatible report.
"
Class {
	#name : 'KGTestTool',
	#superclass : 'Object',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'private - reporting' }
KGTestTool >> exceptionRecordFor: anException stack: stack [
	<arg: #anException type: #Exception>
	<arg: #stack type: #(Array<String>)>
	<return: #(Dictionary<String, Any>)>
	^ OrderedDictionary new
		at: 'class' put: anException class name asString;
		at: 'message' put: anException messageText asString;
		at: 'stack' put: stack;
		yourself
]

{ #category : 'private - running' }
KGTestTool >> projectTestCases [
	<return: #(Array<TestCase>)>
	| package cases |
	package := RPackageOrganizer default packageNamed: 'KlibGenGt-Tests'.
	cases := OrderedCollection new.
	package definedClasses do: [ :eachClass |
		(eachClass inheritsFrom: TestCase) ifTrue: [
			cases addAll: eachClass suite tests ] ].
	^ (cases sorted: [ :a :b |
		a class name = b class name
			ifTrue: [ a selector < b selector ]
			ifFalse: [ a class name < b class name ] ]) asArray
]

{ #category : 'private - reporting' }
KGTestTool >> reportFor: testRecords scope: scope [
	<arg: #testRecords type: #(Array<(Dictionary<String, Any>)>)>
	<arg: #scope type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| failures errors skipped |
	failures := testRecords count: [ :each | (each at: 'status') = 'failure' ].
	errors := testRecords count: [ :each | (each at: 'status') = 'error' ].
	skipped := testRecords count: [ :each | (each at: 'status') = 'skipped' ].
	^ OrderedDictionary new
		at: 'schemaVersion' put: 1;
		at: 'scope' put: scope;
		at: 'successful' put: failures + errors = 0;
		at: 'runCount' put: testRecords size;
		at: 'passedCount' put: testRecords size - failures - errors - skipped;
		at: 'failureCount' put: failures;
		at: 'errorCount' put: errors;
		at: 'skippedCount' put: skipped;
		at: 'tests' put: testRecords;
		yourself
]

{ #category : 'public - running' }
KGTestTool >> run: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| className selectorName testClass selector cases |
	className := aRequest at: 'class' ifAbsent: [ self error: 'test request is missing class' ].
	selectorName := aRequest at: 'selector' ifAbsent: [ nil ].
	testClass := Smalltalk at: className asSymbol ifAbsent: [ self error: 'unknown test class: ' , className ].
	(testClass inheritsFrom: TestCase) ifFalse: [ self error: className , ' is not a TestCase subclass' ].
	selectorName
		ifNil: [ cases := testClass suite tests ]
		ifNotNil: [
			selector := selectorName asSymbol.
			(testClass testSelectors includes: selector) ifFalse: [
				self error: className , ' has no test selector ' , selectorName ].
			cases := { testClass selector: selector } ].
	^ self
		reportFor: (cases collect: [ :test | self runTestCase: test ]) asArray
		scope: (OrderedDictionary new
			at: 'kind' put: (selectorName ifNil: [ 'class' ] ifNotNil: [ 'selector' ]);
			at: 'class' put: className;
			at: 'selector' put: selectorName;
			yourself)
]

{ #category : 'public - running' }
KGTestTool >> runAllProjectTests [
	<return: #(Dictionary<String, Any>)>
	^ self
		reportFor: (self projectTestCases collect: [ :test | self runTestCase: test ])
		scope: (OrderedDictionary new at: 'kind' put: 'project'; yourself)
]

{ #category : 'private - running' }
KGTestTool >> runTestCase: aTestCase [
	<arg: #aTestCase type: #TestCase>
	<return: #(Dictionary<String, Any>)>
	| result exception stack status |
	result := TestResult new.
	[ aTestCase announce: TestCaseStarted withResult: result.
	aTestCase runCaseManaged.
	aTestCase announce: TestCaseEnded withResult: result.
	result addPass: aTestCase ]
		on: TestResult failure , TestResult skip , TestResult warning , TestResult error
		do: [ :caught |
			exception := caught.
			stack := caught signalerContext
				ifNil: [ #() ]
				ifNotNil: [ :context | context shortDebugStack lines asArray ].
			caught sunitAnnounce: aTestCase toResult: result ].
	status := (result failures includes: aTestCase)
		ifTrue: [ 'failure' ]
		ifFalse: [ (result errors includes: aTestCase)
			ifTrue: [ 'error' ]
			ifFalse: [ (result skipped includes: aTestCase)
				ifTrue: [ 'skipped' ]
				ifFalse: [ 'passed' ] ] ].
	^ OrderedDictionary new
		at: 'class' put: aTestCase class name asString;
		at: 'selector' put: aTestCase selector asString;
		at: 'status' put: status;
		at: 'exception' put: (exception
			ifNil: [ nil ]
			ifNotNil: [ self exceptionRecordFor: exception stack: stack ]);
		yourself
]
