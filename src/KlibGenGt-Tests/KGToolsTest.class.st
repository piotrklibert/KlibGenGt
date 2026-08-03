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
		at: 'schema' put: 'klibgen.inventory/2';
		at: 'schemaVersion' put: 2;
		at: 'operation' put: 'inventory';
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
		at: 'warnings' put: #();
		at: 'stateRoot' put: '/tmp/state';
		at: 'recipes' put: #();
		at: 'targets' put: #();
		at: 'artifacts' put: #();
		at: 'references' put: #();
		at: 'workspaces' put: #();
		at: 'stagingAreas' put: #();
		at: 'activeSessions' put: #();
		at: 'statuses' put: #();
		at: 'locks' put: #();
		at: 'storage' put: (Dictionary new at: 'logicalBytes' put: 110; at: 'allocatedBytes' put: 12288; at: 'fileCount' put: 3; yourself);
		yourself)
]

{ #category : 'running' }
KGToolsTest >> setUp [
	| root |
	super setUp.
	root := FileLocator workingDirectory / 'tmp' / 'test-run'.
	KGSession reset; installManifest: (Dictionary new
		at: 'schema' put: 'klibgen.session/1';
		at: 'schemaVersion' put: 1;
		at: 'sessionId' put: 'tools-test';
		at: 'projectKey' put: 'test-project';
		at: 'preset' put: (Dictionary new at: 'name' put: 'gui'; at: 'frontend' put: 'gui'; at: 'sourceChanges' put: 'disabled'; at: 'persistence' put: 'discard'; at: 'startMode' put: 'fresh'; yourself);
		at: 'inputs' put: (Dictionary new at: 'sourceGit' put: (root / 'export/.git') fullName; yourself);
		at: 'paths' put: (Dictionary new at: 'completion' put: (root / 'completion.json') fullName; at: 'eventJournal' put: (root / 'events.jsonl') fullName; yourself);
		yourself)
		sourceChanges: KGDisabledSourceChanges new
		persistence: KGDiscardPersistence new
]

{ #category : 'running' }
KGToolsTest >> tearDown [
	KGSession reset.
	super tearDown
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
KGToolsTest >> testBuildMapRejectsUnknownSchema [
	self
		should: [ KGBuildMap fromDictionary: (Dictionary new at: 'schemaVersion' put: 2; yourself) ]
		raise: Error
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
	self assert: ((methodResult at: 'text') includesSubstring: 'projectName').
	self assert: (methodResult includesKey: 'sha256')
]

{ #category : 'tests - code navigation' }
KGToolsTest >> testClassMethodDumpAndMetadata [
	| dump info packageInfo |
	dump := KGCodeSearchTool new classMethods: (Dictionary new
		at: 'class' put: 'KGCodeSearchTool';
		at: 'packageSet' put: 'project';
		at: 'limit' put: 500;
		yourself).
	self assert: (dump at: 'methods') isNotEmpty.
	self assert: ((dump at: 'methods') allSatisfy: [ :each |
		(each at: 'classification') = 'local' and: [ each includesKey: 'source' ] ]).
	info := KGCodeSearchTool new classInfo: (Dictionary new
		at: 'class' put: 'KGCodeSearchTool';
		at: 'packageSet' put: 'project';
		yourself).
	self assert: ((info at: 'superclasses') includes: 'Object').
	packageInfo := KGCodeSearchTool new packageInfo: (Dictionary new
		at: 'packageName' put: 'KlibGenGt-Tools';
		at: 'packageSet' put: 'project';
		yourself).
	self assert: ((packageInfo at: 'classes') includes: 'KGCodePackageScope').
	self assert: (packageInfo at: 'outgoingDependencies') isNotEmpty
]

{ #category : 'tests - code navigation' }
KGToolsTest >> testCodePackageScopeNamedSetsAndOverrides [
	| first second summary |
	first := KGCodePackageScope forRequest: (Dictionary new
		at: 'packageSet' put: 'project';
		at: 'includePackages' put: #('Kernel' 'Kernel');
		at: 'excludePackages' put: #('KlibGenGt-Core' 'Kernel');
		yourself).
	second := KGCodePackageScope forRequest: (Dictionary new
		at: 'packageSet' put: 'project';
		at: 'includePackages' put: #('Kernel');
		at: 'excludePackages' put: #('Kernel' 'KlibGenGt-Core');
		yourself).
	summary := first summary.
	self assert: (summary at: 'set') equals: 'project'.
	self deny: ((summary at: 'packages') includes: 'Kernel').
	self deny: ((summary at: 'packages') includes: 'KlibGenGt-Core').
	self assert: (summary at: 'fingerprint') equals: (second summary at: 'fingerprint').
	self should: [ KGCodePackageScope forRequest: (Dictionary new
		at: 'packageSet' put: 'project';
		at: 'includePackages' put: #('Definitely-Unknown-Package');
		yourself) ] raise: Error
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
KGToolsTest >> testGuiHooksInstallRepeatedlyAndCleanUp [
	self shouldnt: [
		KGGuiSessionHooks install; install.
		KGGuiSessionHooks shutDown: true.
		KGGuiSessionHooks install; uninstall ] raise: Error
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

{ #category : 'tests - GUI hooks' }
KGToolsTest >> testGuiQuitPromptIsFrontmost [
	| prompt world |
	world := GtWorld new.
	[ KGGuiSessionHooks requestQuitIn: world.
	world root
		childWithId: GtWorldShutdownPromptId
		ifFound: [ :found | prompt := found ]
		ifNone: [ self fail: 'Expected a managed quit prompt' ].
	self assert: world root children last identicalTo: prompt ]
		ensure: [ prompt ifNotNil: [ prompt removeFromParent ] ]
]

{ #category : 'tests - code navigation' }
KGToolsTest >> testMethodAnalysisReturnsAstFactsAndBoundedGraph [
	| result root analysis |
	result := KGMethodAnalysisTool new analyze: (Dictionary new
		at: 'class' put: 'KGCodeSearchTool';
		at: 'selector' put: 'search:';
		at: 'side' put: 'instance';
		at: 'packageSet' put: 'project';
		at: 'depth' put: 0;
		at: 'maxMethods' put: 5;
		at: 'maxCandidates' put: 1;
		at: 'includeSource' put: false;
		yourself).
	root := result at: 'root'.
	analysis := root at: 'analysis'.
	self assert: (root at: 'identity') equals: 'KGCodeSearchTool>>#search:'.
	self assert: (analysis at: 'arguments') equals: #('aRequest').
	self assert: (analysis at: 'variables') isNotEmpty.
	self assert: (analysis at: 'sends') isNotEmpty.
	self deny: (analysis includesKey: 'source').
	self assert: (((result at: 'graph') at: 'nodes') size) equals: 1
]

{ #category : 'tests - code navigation' }
KGToolsTest >> testPackageAwareSearchAccountsBeforeLimit [
	| result counts |
	result := KGCodeSearchTool new search: (Dictionary new
		at: 'query' put: 'search:';
		at: 'kind' put: 'method';
		at: 'in' put: 'selector';
		at: 'match' put: 'exact';
		at: 'packageSet' put: 'project';
		at: 'limit' put: 1;
		yourself).
	counts := result at: 'counts'.
	self assert: (counts at: 'total') > (counts at: 'displayed').
	self assert: (counts at: 'displayed') equals: 1.
	self assert: (counts at: 'inScopeTruncated') > 0.
	self assert: ((result at: 'results') first at: 'package') equals: 'KlibGenGt-Tools'
]

{ #category : 'tests - refactoring' }
KGToolsTest >> testRefactoringASTPatternBlocksRequireExplicitOptIn [
	| request adapter refactoring |
	request := Dictionary new
		at: 'arguments' put: (Dictionary new
			at: 'patternKind' put: 'expression';
			at: 'search' put: '`{ :node | node isLiteralNode }';
			at: 'replace' put: '42';
			yourself);
		at: 'scope' put: (Dictionary new
			at: 'methods' put: {
				Dictionary new
					at: 'class' put: 'KlibGenGt';
					at: 'side' put: 'class';
					at: 'selector' put: 'projectName';
					yourself };
			yourself);
		yourself.
	adapter := KGASTRewriteRefactoringAdapter new.
	self should: [ adapter buildIn: GtRBNamespace new request: request ] raise: Error.
	request at: 'allowPatternBlocks' put: true.
	refactoring := adapter buildIn: GtRBNamespace new request: request.
	self assert: refactoring containsPatternBlocks
]

{ #category : 'tests - refactoring' }
KGToolsTest >> testRefactoringASTRewriteProducesOneLeafChangeWithoutRecursiveTraversal [
	| request model refactoring tool change |
	request := Dictionary new
		at: 'arguments' put: (Dictionary new
			at: 'patternKind' put: 'expression';
			at: 'search' put: '''KlibGenGt''';
			at: 'replace' put: '''KlibGenGtPreview''';
			yourself);
		at: 'scope' put: (Dictionary new
			at: 'methods' put: {
				Dictionary new
					at: 'class' put: 'KlibGenGt';
					at: 'side' put: 'class';
					at: 'selector' put: 'projectName';
					yourself };
			yourself);
		yourself.
	model := GtRBNamespace new.
	refactoring := KGASTRewriteRefactoring model: model request: request.
	refactoring generateChanges.
	change := model changes changes first.
	tool := KGRefactoringTool new.
	self assert: refactoring matchCount equals: 1.
	self assert: (tool perform: #changeCount: with: change) equals: 1.
	self deny: ((tool perform: #changeRecordFor: with: change) includesKey: 'children')
]

{ #category : 'tests - refactoring' }
KGToolsTest >> testRefactoringASTScopeRejectsFrameworkClassesAndPackages [
	| classRequest packageRequest |
	classRequest := Dictionary new
		at: 'scope' put: (Dictionary new at: 'classes' put: #('Object'); yourself);
		yourself.
	packageRequest := Dictionary new
		at: 'scope' put: (Dictionary new at: 'packages' put: #('GToolkit-*'); yourself);
		yourself.
	self
		should: [ (KGASTRewriteRefactoring model: GtRBNamespace new request: classRequest) perform: #methodsFromScope ]
		raise: Error.
	self
		should: [ (KGASTRewriteRefactoring model: GtRBNamespace new request: packageRequest) perform: #methodsFromScope ]
		raise: Error
]

{ #category : 'tests - refactoring' }
KGToolsTest >> testRefactoringImpactCountsLeafChangesAndTonelBytes [
	| model change impact |
	model := GtRBNamespace new.
	model classFor: KlibGenGt.
	model changes addChange: (RBAddMethodChange compile: 'temporaryRefactoringFixture ^ 1' in: KlibGenGt).
	change := model changes changes first.
	impact := KGRefactoringTool new
		perform: #impactFor:tonelChanges:
		with: change
		with: { Dictionary new at: 'before' put: nil; at: 'after' put: 'abc'; yourself }.
	self assert: (impact at: 'semanticChanges') equals: 1.
	self assert: (impact at: 'tonelFiles') equals: 1.
	self assert: (impact at: 'tonelBytes') equals: 3
]

{ #category : 'tests - refactoring' }
KGToolsTest >> testRefactoringParameterAddAdapterBuildsAndGeneratesChanges [
	| request refactoring |
	request := Dictionary new
		at: 'arguments' put: (Dictionary new
			at: 'class' put: 'KGUiSceneGraph';
			at: 'side' put: 'instance';
			at: 'selector' put: 'boundedTextOf:';
			at: 'newSelector' put: 'boundedTextOf:fallback:';
			at: 'insertionIndex' put: 2;
			at: 'name' put: 'fallback';
			at: 'defaultExpression' put: 'nil';
			yourself);
		yourself.
	refactoring := KGParameterAddRefactoringAdapter new
		buildIn: GtRBNamespace new
		request: request.
	self shouldnt: [ refactoring generateChanges ] raise: Error
]

{ #category : 'tests - refactoring' }
KGToolsTest >> testRefactoringRegistryCatalogIsJsonSerializable [
	| catalog encoded decoded |
	catalog := KGRefactoringRegistry new catalog.
	encoded := STONJSON toString: catalog.
	decoded := STONJSON fromString: encoded.
	self assert: (decoded at: 'supported') size equals: 9.
	self assert: (decoded at: 'installed') size > 100
]

{ #category : 'tests - refactoring' }
KGToolsTest >> testRefactoringRegistryExposesNineStableAdaptersAndRuntimeInventory [
	| catalog identifiers methodRename astRewrite |
	catalog := KGRefactoringRegistry new catalog.
	identifiers := (catalog at: 'supported') collect: [ :descriptor | descriptor at: 'id' ].
	self assert: identifiers equals: #('class.rename' 'instance-variable.rename' 'method.extract' 'method.move' 'method.rename' 'parameter.add' 'parameter.remove' 'parameter.rename' 'rewrite.ast').
	methodRename := (catalog at: 'supported') detect: [ :descriptor | (descriptor at: 'id') = 'method.rename' ].
	self assert: (methodRename at: 'requiredArguments') equals: #('class' 'selector' 'newSelector').
	self assert: (methodRename at: 'optionalArguments') equals: #('side' 'argumentPermutation').
	astRewrite := (catalog at: 'supported') detect: [ :descriptor | (descriptor at: 'id') = 'rewrite.ast' ].
	self assert: (astRewrite at: 'requiresScope').
	self assert: ((astRewrite at: 'safety') includes: 'pattern-blocks-require-opt-in').
	self assert: (catalog at: 'installed') size > 100
]

{ #category : 'tests - refactoring' }
KGToolsTest >> testRefactoringSharedDescriptorArraysReproduceStonWriterError [
	| sharedSafety response normalized |
	sharedSafety := #('project-packages-only' 'preview-before-apply').
	response := {
		OrderedDictionary new
			at: 'id' put: 'class.rename';
			at: 'safety' put: sharedSafety;
			yourself.
		OrderedDictionary new
			at: 'id' put: 'method.rename';
			at: 'safety' put: sharedSafety;
			yourself }.
	self should: [ STONJSON toString: response ] raise: STONWriterError.
	normalized := KGRefactoringTool new
		perform: #canonicalObjectFor:
		with: response.
	self deny: (normalized first at: 'safety') == (normalized second at: 'safety').
	self shouldnt: [ STONJSON toString: normalized ] raise: STONWriterError
]

{ #category : 'tests - refactoring' }
KGToolsTest >> testRefactoringToolDiscoveryResponsesAreJsonSerializable [
	| tool responses |
	tool := KGRefactoringTool new.
	responses := {
		tool catalog: Dictionary new.
		tool applicable: (Dictionary new at: 'arguments' put: Dictionary new; yourself).
		tool describe: (Dictionary new at: 'refactoring' put: 'parameter.add'; yourself) }.
	responses do: [ :response |
		self shouldnt: [ STONJSON toString: response ] raise: STONWriterError ]
]

{ #category : 'tests - code navigation' }
KGToolsTest >> testRelationshipQueriesReturnNormalizedMethods [
	| implementors senders pragmas |
	implementors := KGCodeSearchTool new implementors: (Dictionary new
		at: 'selector' put: 'search:';
		at: 'packageSet' put: 'project';
		at: 'limit' put: 20;
		yourself).
	self assert: ((implementors at: 'results') anySatisfy: [ :each |
		(each at: 'class') = 'KGCodeSearchTool' ]).
	senders := KGCodeSearchTool new senders: (Dictionary new
		at: 'selector' put: 'search:';
		at: 'packageSet' put: 'project';
		at: 'limit' put: 20;
		yourself).
	self assert: ((senders at: 'counts') includesKey: 'outOfScope').
	pragmas := KGCodeSearchTool new pragmas: (Dictionary new
		at: 'pragma' put: 'return:';
		at: 'packageSet' put: 'project';
		at: 'limit' put: 1;
		yourself).
	self assert: ((pragmas at: 'counts') at: 'total') > 0
]

{ #category : 'tests - UI control' }
KGToolsTest >> testTcpUiControlConnectorBoundsRequestLines [
	| connector stream |
	connector := KGTcpUiControlConnector new. connector instVarNamed: 'maxRequestBytes' put: 4.
	stream := #[1 2 3 4 5 10] readStream.
	self should: [ connector perform: #readLineFrom: with: stream ] raise: Error
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
KGToolsTest >> testUiControlDefaultsToFileConnector [
	| service |
	service := KGUiControlService new.
	self assert: service connector class equals: KGFileUiControlConnector
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
KGToolsTest >> testUiSceneDepthBoundsTraversalIndependentlyOfNodeLimit [
	| scene root firstChild secondChild grandchild records |
	scene := KGUiSceneGraph new.
	root := BlElement new.
	firstChild := BlElement new.
	secondChild := BlElement new.
	grandchild := BlElement new.
	root addChild: firstChild; addChild: secondChild.
	firstChild addChild: grandchild.
	records := OrderedCollection new.
	scene
		perform: #visit:parent:index:path:into:limit:maxDepth:
		withArguments: { root. nil. 1. #(1). records. 100. 1 }.
	self assert: records size equals: 3.
	self assert: (records noneSatisfy: [ :record | (record at: 'path') size > 2 ]).
	records removeAll.
	scene
		perform: #visit:parent:index:path:into:limit:maxDepth:
		withArguments: { root. nil. 1. #(1). records. 2. nil }.
	self assert: records size equals: 2
]

{ #category : 'tests - UI control' }
KGToolsTest >> testUiSceneEnumeratesParallelUniverseSpaces [
	| spacesMethod |
	spacesMethod := KGUiSceneGraph >> #spaces.
	self assert: (spacesMethod sourceCode includesSubstring: 'BlSpace allOpenSpacesDo:').
	self deny: (spacesMethod sourceCode includesSubstring: 'BlUniverse allInstances')
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
