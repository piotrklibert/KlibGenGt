"
SUnit coverage for structured code, Lepiter, and evaluation CLI tools.

- Slots
  - none
- Public API
  - none; test selectors are invoked by SUnit and document the tool contracts.
"
Class {
	#name : 'KGToolsTest',
	#superclass : 'TestCase',
	#category : 'KlibGenGt-Tests',
	#package : 'KlibGenGt-Tests'
}

{ #category : 'tests' }
KGToolsTest >> testClassAndMethodDefinitionsAreExactText [
	| classResult methodResult |
	classResult := KGCodeSearchTool new classDefinition: (Dictionary new
		at: 'class' put: 'KlibGenGt';
		yourself).
	self assert: ((classResult at: 'text') includesSubstring: 'KlibGenGt').
	methodResult := KGCodeSearchTool new methodSource: (Dictionary new
		at: 'class' put: 'KlibGenGt';
		at: 'selector' put: 'projectName';
		at: 'side' put: 'class';
		yourself).
	self assert: ((methodResult at: 'text') includesSubstring: 'projectName')
]

{ #category : 'tests' }
KGToolsTest >> testCodeSearchReturnsClassesAndMethods [
	| result kinds |
	result := KGCodeSearchTool new search: (Dictionary new
		at: 'query' put: 'KlibGenGt';
		at: 'kind' put: 'all';
		at: 'limit' put: 100;
		yourself).
	kinds := (result at: 'results') collect: [ :each | each at: 'kind' ].
	self assert: (kinds includes: 'class').
	self assert: (kinds includes: 'method')
]

{ #category : 'tests' }
KGToolsTest >> testEvaluationErrorsUseStructuredEnvelope [
	| response error |
	response := KGToolRunner new run: (Dictionary new
		at: 'operation' put: 'eval';
		at: 'expression' put: '1 / 0';
		yourself).
	self deny: (response at: 'ok').
	error := response at: 'error'.
	self assert: (error at: 'class') isString.
	self assert: (error at: 'stack') isCollection
]

{ #category : 'tests' }
KGToolsTest >> testEvaluationResultAndProfileAreSerializable [
	| response encoded decoded |
	response := KGToolRunner new run: (Dictionary new
		at: 'operation' put: 'eval';
		at: 'expression' put: '40 + 2';
		at: 'profile' put: true;
		yourself).
	self assert: (response at: 'ok').
	self assert: ((response at: 'data') at: 'result') equals: '42'.
	self assert: ((response at: 'data') includesKey: 'profile').
	encoded := STONJSON toString: response.
	decoded := STONJSON fromString: encoded.
	self assert: (decoded at: 'ok')
]

{ #category : 'tests' }
KGToolsTest >> testGtBookCanBeSearchedAndIdentified [
	| tool result |
	tool := KGLepiterTool new.
	self assert: (tool databaseName: LeDatabase gtBook) equals: 'Glamorous Toolkit Book'.
	result := tool search: (Dictionary new
		at: 'query' put: 'Glamorous';
		at: 'in' put: 'title';
		at: 'databases' put: #('Glamorous Toolkit Book');
		at: 'limit' put: 5;
		yourself).
	self assert: (result at: 'count') > 0.
	self assert: ((result at: 'results') allSatisfy: [ :each |
		(each at: 'database') = 'Glamorous Toolkit Book' ])
]

{ #category : 'tests - GUI hooks' }
KGToolsTest >> testGuiHooksAppendCommitEventRecord [
	| eventPath exportPath records last environment previousEvent previousExport |
	environment := Smalltalk os environment.
	previousEvent := environment at: 'KLIBGEN_GUI_EVENT_PATH' ifAbsent: [ nil ].
	previousExport := environment at: 'KLIBGEN_EXPORT_GIT' ifAbsent: [ nil ].
	eventPath := FileLocator workingDirectory / 'tmp' / UUID new asString / 'events.jsonl'.
	exportPath := FileLocator workingDirectory / 'tmp' / 'test-run' / 'export'.
	[ environment
		at: 'KLIBGEN_GUI_EVENT_PATH' put: eventPath fullName;
		at: 'KLIBGEN_EXPORT_GIT' put: (exportPath / '.git') fullName.
	KGGuiSessionHooks emitIcebergCommittedForRepositoryPath: exportPath fullName.
	records := eventPath contents lines.
	self assert: records size equals: 1.
	last := STONJSON fromString: records last.
	self assert: (last at: 'event') equals: 'iceberg-committed'.
	self assert: (last at: 'repositoryPath') equals: exportPath fullName ]
		ensure: [
			previousEvent
				ifNil: [ environment removeKey: 'KLIBGEN_GUI_EVENT_PATH' ]
				ifNotNil: [ environment at: 'KLIBGEN_GUI_EVENT_PATH' put: previousEvent ].
			previousExport
				ifNil: [ environment removeKey: 'KLIBGEN_EXPORT_GIT' ]
				ifNotNil: [ environment at: 'KLIBGEN_EXPORT_GIT' put: previousExport ].
			eventPath parent ensureDeleteAll ]
]

{ #category : 'tests - GUI hooks' }
KGToolsTest >> testGuiHooksFilterTheExactRunRepository [
	| exportPath environment previousExport |
	environment := Smalltalk os environment.
	previousExport := environment at: 'KLIBGEN_EXPORT_GIT' ifAbsent: [ nil ].
	exportPath := FileLocator workingDirectory / 'tmp' / 'test-run' / 'export'.
	[ environment at: 'KLIBGEN_EXPORT_GIT' put: (exportPath / '.git') fullName.
	self assert: (KGGuiSessionHooks handlesRepositoryPath: exportPath fullName).
	self deny: (KGGuiSessionHooks handlesRepositoryPath: (exportPath parent / 'another-export') fullName) ]
		ensure: [ previousExport
			ifNil: [ environment removeKey: 'KLIBGEN_EXPORT_GIT' ]
			ifNotNil: [ environment at: 'KLIBGEN_EXPORT_GIT' put: previousExport ] ]
]

{ #category : 'tests - GUI hooks' }
KGToolsTest >> testGuiHooksInstallRepeatedlyAndCleanUp [
	self shouldnt: [
		KGGuiSessionHooks install; install.
		KGGuiSessionHooks shutDown: true.
		KGGuiSessionHooks install; uninstall ] raise: Error
]
