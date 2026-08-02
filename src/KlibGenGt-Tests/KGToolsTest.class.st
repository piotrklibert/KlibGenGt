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

{ #category : 'running' }
KGToolsTest >> setUp [
	| root |
	super setUp.
	root := FileLocator workingDirectory / 'tmp' / 'test-run'.
	KGSession reset; installManifest: (Dictionary new
		at: 'sessionId' put: 'tools-test';
		at: 'preset' put: (Dictionary new at: 'startMode' put: 'fresh'; yourself);
		at: 'inputs' put: (Dictionary new at: 'sourceGit' put: (root / 'export/.git') fullName; yourself);
		at: 'paths' put: (Dictionary new at: 'eventJournal' put: (root / 'events.jsonl') fullName; yourself);
		yourself)
		sourceChanges: KGDisabledSourceChanges new
		persistence: KGDiscardPersistence new
]

{ #category : 'running' }
KGToolsTest >> tearDown [
	KGSession reset.
	super tearDown
]

{ #category : 'private - fixtures' }
KGToolsTest >> buildMapFixture [
	<return: #KGBuildMap>
	^ KGBuildMap fromDictionary: (Dictionary new
		at: 'schema' put: 'klibgen.inventory/2';
		at: 'schemaVersion' put: 2;
		at: 'generatedAt' put: '2026-08-01T00:00:00Z';
		at: 'nodes' put: {
			Dictionary new
				at: 'id' put: 'target:cli';
				at: 'kind' put: 'target';
				at: 'label' put: 'cli';
				at: 'status' put: 'resolved';
				at: 'logicalBytes' put: 0;
				at: 'allocatedBytes' put: 0;
				at: 'fileCount' put: 0;
				at: 'components' put: #();
				at: 'characteristics' put: Dictionary new;
				at: 'aggregate' put: false;
				yourself.
			Dictionary new
				at: 'id' put: 'step:runtime';
				at: 'kind' put: 'step';
				at: 'label' put: 'runtime';
				at: 'status' put: 'resolved';
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
				at: 'label' put: 'runtime abc';
				at: 'status' put: 'verified';
				at: 'logicalBytes' put: 100;
				at: 'allocatedBytes' put: 8192;
				at: 'fileCount' put: 2;
				at: 'components' put: #();
				at: 'characteristics' put: Dictionary new;
				at: 'aggregate' put: false;
				yourself };
		at: 'edges' put: {
			Dictionary new
				at: 'id' put: 'edge:target-step';
				at: 'kind' put: 'recipe-sequence';
				at: 'source' put: 'target:cli';
				at: 'target' put: 'step:runtime';
				at: 'characteristics' put: Dictionary new;
				yourself.
			Dictionary new
				at: 'id' put: 'edge:one';
				at: 'kind' put: 'step-artifact';
				at: 'source' put: 'step:runtime';
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
	filtered := map filteredByKind: 'artifact' status: 'verified'.
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
	self assert: artifactElement text asString equals: 'runtime abc'.
	self assert: edgeElement class equals: BlLineElement.
	self assert: edgeElement eventDispatcher handlers size >= 2.
	self assert: tooltip children size equals: 3.
	self assert: tooltip children first text asString equals: 'runtime abc'.
	self assert: tooltip children second text asString equals: 'Status: verified'.
	self assert: tooltip children third text asString equals: '100 B logical / 8.0 KiB allocated'.
	self assert: overview topStep root graph nodeChildren size equals: 3.
	self assert: graph topStep root graph nodeChildren size equals: 3
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
	eventPath := FileLocator workingDirectory / 'tmp' / 'test-run' / 'events.jsonl'.
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

{ #category : 'tests - GUI export' }
KGToolsTest >> testGuiExportButtonActsAndRefreshesThroughExistingSpaceScripter [
	| temporary tool button space scripter deadline |
	temporary := KGExportTool
		subclass: #KGTemporaryExportTool
		instanceVariableNames: 'count exports'
		classVariableNames: ''
		package: 'KlibGen-Build-Transient'.
	[ temporary compile: 'initialize super initialize. count := 2. exports := 0'.
	temporary compile: 'changeCount ^ count'.
	temporary compile: 'exportChanges exports := exports + 1. count := 0'.
	temporary compile: 'exports ^ exports'.
	tool := temporary new.
	button := KGExportButton new.
	button instVarNamed: 'tool' put: tool.
	button aptitude: BrGlamorousButtonWithIconAptitude new.
	space := BlSpace new extent: 200 @ 100.
	space root addChild: button.
	button perform: #updateCount: with: 2.
	space pulse.
	self assert: button label asString equals: 'Export (2)'.
	self deny: button isDisabled.
	scripter := KGExistingSpaceScripter new attachToSpace: space.
	[ scripter act: 'click' on: button request: Dictionary new.
	deadline := DateAndTime now + 2 seconds.
	[ tool exports = 1 or: [ DateAndTime now > deadline ] ]
		whileFalse: [ (Delay forMilliseconds: 20) wait ].
	self assert: tool exports equals: 1.
	deadline := DateAndTime now + 2 seconds.
	[ button label asString = 'Export (0)' or: [ DateAndTime now > deadline ] ]
		whileFalse: [ (Delay forMilliseconds: 20) wait ].
	self assert: button label asString equals: 'Export (0)'.
	self assert: button isDisabled ]
		ensure: [ scripter detach ] ]
		ensure: [
			space ifNotNil: [ space close ].
			temporary removeFromSystem ]
]

{ #category : 'tests - GUI export' }
KGToolsTest >> testGuiExportWorldCustomizationIsIdempotentAndRemovable [
	| world |
	world := GtWorld new.
	[ KGExportButton installOn: world; installOn: world.
	self assert: (world root query // KGExportButton) all size equals: 1.
	KGExportButton uninstallFrom: world.
	self assert: (world root query // KGExportButton) all size equals: 0 ]
		ensure: [
			KGExportButton uninstallFrom: world.
			world close ]
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

{ #category : 'tests - UI control' }
KGToolsTest >> testExistingSpaceScripterAttachmentPreservesHierarchy [
	| space parent child scripter |
	space := BlSpace new.
	parent := BlElement new.
	child := BlElement new.
	space root addChild: parent.
	parent addChild: child.
	scripter := KGExistingSpaceScripter new.
	[ scripter attachToSpace: space.
	self assert: child parent identicalTo: parent.
	self assert: parent parent identicalTo: space root.
	self assert: scripter space identicalTo: space ]
		ensure: [ scripter detach ]
]

{ #category : 'tests - UI control' }
KGToolsTest >> testExistingSpaceScripterDispatchesClickWithoutReparenting [
	| space target clicks scripter |
	space := BlSpace new extent: 100 @ 100.
	target := BlElement new size: 20 @ 20.
	clicks := 0.
	target when: BlClickEvent do: [ :event | clicks := clicks + 1. event consumed: true ].
	space root addChild: target.
	space pulse.
	scripter := KGExistingSpaceScripter new attachToSpace: space.
	[ scripter act: 'click' on: target request: Dictionary new.
	self assert: clicks equals: 1.
	self assert: target parent identicalTo: space root ]
		ensure: [ scripter detach ]
]

{ #category : 'tests - UI control' }
KGToolsTest >> testUiSceneHandlesAreStableAndDetachedHandlesFail [
	| scene space element first second |
	scene := KGUiSceneGraph new.
	space := BlSpace new.
	element := BlElement new.
	space root addChild: element.
	first := scene perform: #handleFor: with: element.
	second := scene perform: #handleFor: with: element.
	self assert: first equals: second.
	self assert: (scene elementAt: first) identicalTo: element.
	element removeFromParent.
	self should: [ scene elementAt: first ] raise: Error
]

{ #category : 'tests - UI control' }
KGToolsTest >> testUiControlRejectsInvalidEnvelopeAndContinues [
	| service request response |
	service := KGUiControlService new.
	service instVarNamed: 'sessionId' put: 'test-session'.
	request := Dictionary new
		at: 'schemaVersion' put: 9;
		at: 'requestId' put: 'bad';
		at: 'sessionId' put: 'test-session';
		at: 'operation' put: 'ui.status';
		at: 'deadlineUnixMs' put: DateAndTime now asUnixTime * 1000 + 5000;
		yourself.
	self should: [ service handle: request ] raise: Error.
	request at: 'schemaVersion' put: 1; at: 'requestId' put: 'good'.
	response := service handle: request.
	self assert: (response at: 'ok').
	self assert: (response at: 'requestId') equals: 'good'
]

{ #category : 'tests - UI control' }
KGToolsTest >> testUiControlBatchStopsAtFirstFailure [
	| service request result |
	service := KGUiControlService new.
	service instVarNamed: 'sessionId' put: 'test-session'.
	request := Dictionary new
		at: 'requestId' put: 'batch';
		at: 'sessionId' put: 'test-session';
		at: 'deadlineUnixMs' put: DateAndTime now asUnixTime * 1000 + 5000;
		at: 'steps' put: {
			Dictionary new at: 'operation' put: 'ui.status'; yourself.
			Dictionary new at: 'operation' put: 'ui.unsupported'; yourself.
			Dictionary new at: 'operation' put: 'ui.status'; yourself };
		yourself.
	result := service perform: #batch: with: request.
	self assert: (result at: 'completedCount') equals: 1.
	self assert: (result at: 'failedStep') equals: 2.
	self assert: (result at: 'failure') notNil
]

{ #category : 'tests - UI control' }
KGToolsTest >> testUiControlLiveEvaluationSuccessAndTimeout [
	| service request result |
	service := KGUiControlService new.
	request := Dictionary new
		at: 'expression' put: '40 + 2';
		at: 'deadlineUnixMs' put: DateAndTime now asUnixTime * 1000 + 5000;
		yourself.
	result := service perform: #evaluate: with: request.
	self assert: (result at: 'result') equals: '42'.
	request
		at: 'expression' put: '(Delay forMilliseconds: 200) wait';
		at: 'deadlineUnixMs' put: DateAndTime now asUnixTime * 1000 + 10.
	self should: [ service perform: #evaluate: with: request ] raise: Error
]

{ #category : 'tests - UI control' }
KGToolsTest >> testUiControlDefaultsToFileConnector [
	| service |
	service := KGUiControlService new.
	self assert: service connector class equals: KGFileUiControlConnector
]

{ #category : 'tests - UI control' }
KGToolsTest >> testUiControlSerializedRequestReturnsStructuredFailure [
	| service response |
	service := KGUiControlService new.
	service instVarNamed: 'sessionId' put: 'test-session'.
	response := service responseForSerializedRequest: '{' defaultRequestId: 'fallback'.
	self deny: (response at: 'ok').
	self assert: (response at: 'requestId') equals: 'fallback'.
	self assert: (response at: 'sessionId') equals: 'test-session'
]

{ #category : 'tests - UI control' }
KGToolsTest >> testTcpUiControlConnectorSupportsEndpointLifecycle [
	| connector |
	connector := KGTcpUiControlConnector onPort: 0.
	connector instVarNamed: 'boundPort' put: 4242.
	[
	self assert: connector boundPort equals: 4242.
	self assert: (connector endpoint at: 'host') equals: '127.0.0.1'.
	self assert: (connector endpoint at: 'framing') equals: 'ndjson' ]
		ensure: [ connector stop ].
	self assert: connector boundPort equals: 0
]

{ #category : 'tests - UI control' }
KGToolsTest >> testTcpUiControlConnectorBoundsRequestLines [
	| connector stream |
	connector := KGTcpUiControlConnector new. connector instVarNamed: 'maxRequestBytes' put: 4.
	stream := #[1 2 3 4 5 10] readStream.
	self should: [ connector perform: #readLineFrom: with: stream ] raise: Error
]

{ #category : 'tests - GUI hooks' }
KGToolsTest >> testGuiHooksInstallQuitPolicyIdempotently [
	| world closeHandlers shutdownListeners |
	world := GtWorld new.
	[ KGGuiSessionHooks
		ensureQuitPolicyOn: world;
		ensureQuitPolicyOn: world.
	closeHandlers := OrderedCollection new.
	shutdownListeners := OrderedCollection new.
	world eventDispatcher handlersDo: [ :eachHandler |
		(eachHandler isKindOf: KGGuiWorldCloseEventHandler)
			ifTrue: [ closeHandlers add: eachHandler ].
		(eachHandler isKindOf: BlSpaceShutdownOnCloseListener)
			ifTrue: [ shutdownListeners add: eachHandler ] ].
	self assert: closeHandlers size equals: 1.
	self assert: shutdownListeners size equals: 1 ]
		ensure: [
			world removeShutdownListener.
			world removeEventHandlersSuchThat: [ :eachHandler |
				eachHandler isKindOf: KGGuiWorldCloseEventHandler ].
			world close ]
]

{ #category : 'tests - GUI hooks' }
KGToolsTest >> testGuiQuitMenuUsesSessionQuitPolicy [
	| menuMethod |
	menuMethod := GtToolsMenu >> #quitFrom:.
	self assert: menuMethod package name equals: 'KlibGenGt-Tools'.
	self assert: (menuMethod sourceCode includesSubstring: 'KGGuiSessionHooks requestQuitFrom: button')
]

{ #category : 'tests - GUI hooks' }
KGToolsTest >> testGuiQuitPolicyConfirmsRestorableToolState [
	| toolTab world |
	world := GtWorld new.
	[ KGGuiSessionHooks ensureQuitPolicyOn: world.
	self deny: (KGGuiSessionHooks shouldConfirmQuitIn: world).
	toolTab := BrTab new
		aptitude: BrGlamorousTabAptitude;
		label: 'Test tool';
		stencil: [ BlElement new ].
	world tabGroup addTab: toolTab.
	self assert: (KGGuiSessionHooks shouldConfirmQuitIn: world).
	world tabGroup removeTab: toolTab.
	self assert: (KGGuiSessionHooks shouldConfirmQuitIn: world) ]
		ensure: [ KGGuiSessionHooks shutDown: false ]
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
