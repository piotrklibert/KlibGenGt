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

{ #category : 'private - fixtures' }
KGToolsTest >> buildMapFixture [
	<return: #KGBuildMap>
	^ KGBuildMap fromDictionary: (Dictionary new
		at: 'schemaVersion' put: 1;
		at: 'generatedAt' put: '2026-08-01T00:00:00Z';
		at: 'nodes' put: {
			Dictionary new
				at: 'id' put: 'layer:L01';
				at: 'kind' put: 'layer';
				at: 'label' put: 'L01';
				at: 'status' put: 'defined';
				at: 'contextId' put: nil;
				at: 'logicalBytes' put: 10;
				at: 'allocatedBytes' put: 4096;
				at: 'fileCount' put: 1;
				at: 'components' put: #();
				at: 'characteristics' put: Dictionary new;
				at: 'aggregate' put: false;
				yourself.
			Dictionary new
				at: 'id' put: 'artifact:one';
				at: 'kind' put: 'artifact';
				at: 'label' put: 'L01 abc';
				at: 'status' put: 'current';
				at: 'contextId' put: 'default';
				at: 'logicalBytes' put: 100;
				at: 'allocatedBytes' put: 8192;
				at: 'fileCount' put: 2;
				at: 'components' put: #();
				at: 'characteristics' put: Dictionary new;
				at: 'aggregate' put: false;
				yourself };
		at: 'edges' put: {
			Dictionary new
				at: 'id' put: 'edge:one';
				at: 'kind' put: 'artifact-layer';
				at: 'source' put: 'layer:L01';
				at: 'target' put: 'artifact:one';
				at: 'characteristics' put: Dictionary new;
				yourself };
		yourself)
]

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

{ #category : 'tests - build map' }
KGToolsTest >> testBuildMapFiltersAndRelationships [
	| map artifact filtered |
	map := self buildMapFixture.
	artifact := map nodeAt: 'artifact:one'.
	self assert: artifact relationships size equals: 1.
	filtered := map filteredByContext: 'default' kind: 'artifact' status: 'current'.
	self assert: filtered visibleNodes size equals: 1.
	self assert: filtered visibleNodes first id equals: 'artifact:one'.
	self assert: (map humanBytes: 1073741824) equals: '1.0 GiB'
]

{ #category : 'tests - build map' }
KGToolsTest >> testBuildMapMondrianPresentationsBuild [
	| map overview graph artifactElement edgeElement tooltip |
	map := self buildMapFixture.
	overview := map overviewMondrian.
	graph := map graphMondrian.
	artifactElement := map nodeElementFor: (map nodeAt: 'artifact:one').
	edgeElement := map edgeElement.
	tooltip := map nodeTooltipElementFor: (map nodeAt: 'artifact:one').
	self assert: overview class equals: GtMondrian.
	self assert: graph class equals: GtMondrian.
	self assert: artifactElement text asString equals: 'L01 abc'.
	self assert: edgeElement class equals: BlLineElement.
	self assert: edgeElement eventDispatcher handlers size >= 2.
	self assert: tooltip children size equals: 3.
	self assert: tooltip children first text asString equals: 'L01 abc'.
	self assert: tooltip children second text asString equals: 'Status: current'.
	self assert: tooltip children third text asString equals: '100 B logical / 8.0 KiB allocated'.
	self assert: overview topStep root graph nodeChildren size equals: 4.
	self assert: graph topStep root graph nodeChildren size equals: 2
]

{ #category : 'tests - build map' }
KGToolsTest >> testBuildMapEdgeHoverHighlightsConnection [
	| map graph edge connectedNodes |
	map := self buildMapFixture.
	graph := map graphMondrian.
	edge := graph topStep root graph edgeChildren first.
	connectedNodes := OrderedCollection new.
	edge graph connectedNodes do: [ :each | connectedNodes add: each ].
	self assert: connectedNodes size equals: 2.

	edge fireEvent: BlMouseEnterEvent new.
	self assert: edge border width equals: 4.
	self assert: (connectedNodes allSatisfy: [ :each | each border width = 4 ]).

	edge fireEvent: BlMouseLeaveEvent new.
	self assert: edge border width equals: 2.
	self assert: (connectedNodes allSatisfy: [ :each | each border width = 2 ])
]

{ #category : 'tests - build map' }
KGToolsTest >> testBuildMapRejectsUnknownSchema [
	self
		should: [ KGBuildMap fromDictionary: (Dictionary new at: 'schemaVersion' put: 2; yourself) ]
		raise: Error
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

{ #category : 'tests - test tool' }
KGToolsTest >> testTestToolCapturesFailuresAndErrors [
	| temporary failure error |
	temporary := TestCase
		subclass: #KGTemporaryRecordingTest
		instanceVariableNames: ''
		classVariableNames: ''
		package: 'KlibGen-Build-Transient'.
	[ temporary compile: 'testFailure self assert: false'.
	temporary compile: 'testError self error: ''diagnostic boom'''.
	failure := KGTestTool new run: (Dictionary new
		at: 'operation' put: 'test.run';
		at: 'class' put: temporary name asString;
		at: 'selector' put: 'testFailure';
		yourself).
	error := KGTestTool new run: (Dictionary new
		at: 'operation' put: 'test.run';
		at: 'class' put: temporary name asString;
		at: 'selector' put: 'testError';
		yourself).
	self deny: (failure at: 'successful').
	self assert: ((failure at: 'tests') first at: 'status') equals: 'failure'.
	self assert: ((error at: 'tests') first at: 'status') equals: 'error'.
	self assert: ((((error at: 'tests') first at: 'exception') at: 'message') includesSubstring: 'diagnostic boom').
	self deny: ((((error at: 'tests') first at: 'exception') at: 'stack') isEmpty) ]
		ensure: [ temporary removeFromSystem ]
]

{ #category : 'tests - test tool' }
KGToolsTest >> testTestToolRunsOnePassingSelector [
	| report |
	report := KGTestTool new run: (Dictionary new
		at: 'operation' put: 'test.run';
		at: 'class' put: 'KlibGenGtTest';
		at: 'selector' put: 'testProjectName';
		yourself).
	self assert: (report at: 'successful').
	self assert: (report at: 'runCount') equals: 1.
	self assert: ((report at: 'tests') first at: 'status') equals: 'passed'
]
