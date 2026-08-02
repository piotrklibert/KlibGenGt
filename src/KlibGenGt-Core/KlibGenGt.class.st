"
KlibGenGt package map:

{{gtExample:KlibGenGt class>>#classHierarchyMondrian|previewExpanded=true|previewShow=#gtLiveFor:|noCode=true|previewHeight=360}}

- Slots
  - none
- Public API
  - {{gtMethod:KlibGenGt class>>#projectName}} - Answer the project name used in smoke tests and examples.
  - {{gtMethod:KlibGenGt class>>#sampleGreeting}} - Answer a small deterministic greeting for smoke tests.
  - {{gtMethod:KlibGenGt class>>#classHierarchyClasses}} - Answer project classes plus explicit hierarchy roots.
  - {{gtMethod:KlibGenGt class>>#classHierarchyRootClasses}} - Answer explicit roots included in the visualization.
  - {{gtMethod:KlibGenGt class>>#classHierarchyParentOf:in:}} - Find the nearest included superclass for one class.
  - {{gtMethod:KlibGenGt class>>#classHierarchyChildrenFor:in:}} - Find direct visualization children for one class.
  - {{gtMethod:KlibGenGt class>>#classHierarchyMondrian}} - Build the Mondrian inheritance visualization embedded above.
  - {{gtMethod:KlibGenGt class>>#exportClassHierarchyPngTo:}} - Export the inheritance visualization to a PNG file.
- Core
  - {{gtClass:KGBuildProvenance}} - Stores immutable construction provenance embedded in canonical images.
  - {{gtClass:KlibGenGt}} - Project anchor class and small package-level accessors.
  - {{gtClass:KGHtmlNode}} - Abstract base for simplified legacy HTML AST nodes.
  - {{gtClass:KGHtmlDocument}} - Root AST node that owns the parsed top-level nodes.
  - {{gtClass:KGHtmlElement}} - AST node for an HTML element with ordered attributes and children.
  - {{gtClass:KGHtmlText}} - AST node for literal text between legacy HTML constructs.
  - {{gtClass:KGLegacyCodeBlock}} - AST node for non-HTML legacy `--kod=...` code blocks.
  - {{gtClass:KGHtmlGrammar}} - PetitParser2 grammar for the simplified HTML subset used by legacy posts.
  - {{gtClass:KGHtmlParser}} - Parser layer that maps the simplified HTML grammar into AST nodes.
  - {{gtClass:KGLegacyPostParser}} - Parser extension that adds legacy post-only constructs on top of HTML.
  - {{gtClass:KGLegacyPostTransformContext}} - Value object carrying transform parameters such as `fname`, `link`, and `pubdate`.
  - {{gtClass:KGLegacyPostTransformer}} - Smalltalk implementation of the legacy post HTML rewrite rules.
- Examples
  - {{gtClass:KGMethodArgChecker}} - Example utility for checking method argument conventions.
  - {{gtClass:KGScratchPadScripts}} - Scratchpad entry points for exploratory project scripts.
- Environment
  - {{gtClass:KGCheckTypePragmas}} - Validates documentation type expressions in class comments and pragmas.
- DB
  - {{gtClass:KGSQLite3Examples}} - Provides staged diagnostics and examples for SQLite3 library operations.
- Kotlin
  - {{gtClass:KGKotlinFile}} - Root AST node for one parsed Kotlin source file.
  - {{gtClass:KGKotlinImport}} - AST node for one Kotlin import directive.
  - {{gtClass:KGKotlinDeclaration}} - Abstract base for Kotlin declaration AST nodes.
  - {{gtClass:KGKotlinTypeDeclaration}} - AST node for a Kotlin class, interface, or object declaration.
  - {{gtClass:KGKotlinFunctionDeclaration}} - AST node for a Kotlin function or extension function declaration.
  - {{gtClass:KGKotlinTypeAliasDeclaration}} - AST node for a Kotlin type alias declaration.
  - {{gtClass:KGKotlinParameter}} - AST node for a Kotlin function or constructor parameter.
  - {{gtClass:KGKotlinGrammar}} - PetitParser2 entry grammar for Kotlin source text.
  - {{gtClass:KGKotlinParser}} - Parser and declaration extractor for the Kotlin subset used by samples.
- Tools
  - {{gtClass:KGJsonRecord}} - Provides shared validation and serialization for generated immutable JSON records.
  - {{gtClass:KGJsonModelRegistry}} - Dispatches named build JSON schemas to their generated record classes.
  - GENERATED-JSON-MODELS-BEGIN
  - {{gtClass:KGArtifactListV1}} - Generated immutable JSON record for `ArtifactListV1`.
  - {{gtClass:KGArtifactV1}} - Generated immutable JSON record for `ArtifactV1`.
  - {{gtClass:KGArtifactVerificationV1}} - Generated immutable JSON record for `ArtifactVerificationV1`.
  - {{gtClass:KGBuildResultV1}} - Generated immutable JSON record for `BuildResultV1`.
  - {{gtClass:KGBuildStatusV1}} - Generated immutable JSON record for `BuildStatusV1`.
  - {{gtClass:KGDoctorV1}} - Generated immutable JSON record for `DoctorV1`.
  - {{gtClass:KGGcPlanV1}} - Generated immutable JSON record for `GcPlanV1`.
  - {{gtClass:KGInventoryV2}} - Generated immutable JSON record for `InventoryV2`.
  - {{gtClass:KGJsonErrorRecord}} - Generated immutable JSON record for `ErrorRecord`.
  - {{gtClass:KGJsonInvalidArtifactRecord}} - Generated immutable JSON record for `InvalidArtifactRecord`.
  - {{gtClass:KGJsonInventoryEdgeRecord}} - Generated immutable JSON record for `InventoryEdgeRecord`.
  - {{gtClass:KGJsonInventoryNodeRecord}} - Generated immutable JSON record for `InventoryNodeRecord`.
  - {{gtClass:KGJsonInventoryRecipeRecord}} - Generated immutable JSON record for `InventoryRecipeRecord`.
  - {{gtClass:KGJsonInventoryStepRecord}} - Generated immutable JSON record for `InventoryStepRecord`.
  - {{gtClass:KGJsonInventoryTargetRecord}} - Generated immutable JSON record for `InventoryTargetRecord`.
  - {{gtClass:KGJsonLaunchPresetRecord}} - Generated immutable JSON record for `LaunchPresetRecord`.
  - {{gtClass:KGJsonMalformedRecord}} - Generated immutable JSON record for `MalformedRecord`.
  - {{gtClass:KGJsonMeasurementStorageRecord}} - Generated immutable JSON record for `MeasurementStorageRecord`.
  - {{gtClass:KGJsonPathDigestFileRecord}} - Generated immutable JSON record for `PathDigestFileRecord`.
  - {{gtClass:KGJsonPathDigestRecord}} - Generated immutable JSON record for `PathDigestRecord`.
  - {{gtClass:KGJsonPathStorageRecord}} - Generated immutable JSON record for `PathStorageRecord`.
  - {{gtClass:KGJsonPromotionRecord}} - Generated immutable JSON record for `PromotionRecord`.
  - {{gtClass:KGJsonPublishedArtifactRecord}} - Generated immutable JSON record for `PublishedArtifactRecord`.
  - {{gtClass:KGJsonRecipeCatalogTargetRecord}} - Generated immutable JSON record for `RecipeCatalogTargetRecord`.
  - {{gtClass:KGJsonRenameRecord}} - Generated immutable JSON record for `RenameRecord`.
  - {{gtClass:KGJsonResolvedStepRecord}} - Generated immutable JSON record for `ResolvedStepRecord`.
  - {{gtClass:KGJsonSessionPathsRecord}} - Generated immutable JSON record for `SessionPathsRecord`.
  - {{gtClass:KGJsonStagingChangesRecord}} - Generated immutable JSON record for `StagingChangesRecord`.
  - {{gtClass:KGJsonStepImplementationRecord}} - Generated immutable JSON record for `StepImplementationRecord`.
  - {{gtClass:KGJsonStorageRecord}} - Generated immutable JSON record for `StorageRecord`.
  - {{gtClass:KGJsonSuffixStorageRecord}} - Generated immutable JSON record for `SuffixStorageRecord`.
  - {{gtClass:KGJsonToolCheckRecord}} - Generated immutable JSON record for `ToolCheckRecord`.
  - {{gtClass:KGMeasurementV1}} - Generated immutable JSON record for `MeasurementV1`.
  - {{gtClass:KGRecipeCatalogV1}} - Generated immutable JSON record for `RecipeCatalogV1`.
  - {{gtClass:KGReferenceV1}} - Generated immutable JSON record for `ReferenceV1`.
  - {{gtClass:KGResolvedRecipeV1}} - Generated immutable JSON record for `ResolvedRecipeV1`.
  - {{gtClass:KGSessionCompletionV1}} - Generated immutable JSON record for `SessionCompletionV1`.
  - {{gtClass:KGSessionReadyV1}} - Generated immutable JSON record for `SessionReadyV1`.
  - {{gtClass:KGSessionV1}} - Generated immutable JSON record for `SessionV1`.
  - {{gtClass:KGSourceLockV1}} - Generated immutable JSON record for `SourceLockV1`.
  - {{gtClass:KGStagingListV1}} - Generated immutable JSON record for `StagingListV1`.
  - {{gtClass:KGStagingResultV1}} - Generated immutable JSON record for `StagingResultV1`.
  - {{gtClass:KGStagingV1}} - Generated immutable JSON record for `StagingV1`.
  - {{gtClass:KGStatusListV1}} - Generated immutable JSON record for `StatusListV1`.
  - {{gtClass:KGWorkspaceResetV1}} - Generated immutable JSON record for `WorkspaceResetV1`.
  - {{gtClass:KGWorkspaceStatusV1}} - Generated immutable JSON record for `WorkspaceStatusV1`.
  - {{gtClass:KGWorkspaceV1}} - Generated immutable JSON record for `WorkspaceV1`.
  - GENERATED-JSON-MODELS-END
  - {{gtClass:KGSession}} - Holds immutable launch state and the installed process capabilities.
  - {{gtClass:KGSessionBootstrap}} - Validates session manifests and authors lifecycle records.
  - {{gtClass:KGOperationResult}} - Normalizes operation results into the stable response envelope.
  - {{gtClass:KGAtomicJsonWriter}} - Publishes lifecycle JSON records through same-directory replacement.
  - {{gtClass:KGDisabledSourceChanges}} - Enforces read-only source behavior.
  - {{gtClass:KGInteractiveSourceChanges}} - Exports GUI source changes through an explicit session repository.
  - {{gtClass:KGStagedSourceChanges}} - Exports agentic changes into a durable staging repository.
  - {{gtClass:KGDiscardPersistence}} - Enforces discard-only image persistence.
  - {{gtClass:KGWorkspacePersistence}} - Enforces save-or-discard lifecycle for the mutable GUI workspace.
  - {{gtClass:KGToolRegistration}} - Describes a versioned registered image tool.
  - {{gtClass:KGToolRegistry}} - Resolves structured operations without equality-chain dispatch.
  - {{gtClass:KGExportTool}} - Counts modified KlibGenGt packages and commits live changes in a managed GUI export repository.
  - {{gtClass:KGExportButton}} - Adds the live export count and commit action to the GT world toolbar.
  - {{gtClass:KGGuiSessionHooks}} - Controls GUI quit confirmation and emits lifecycle and exact-repository Iceberg commit events for host-side promotion.
  - {{gtClass:KGUiControlConnector}} - Defines connector-neutral UI-control transport lifecycle.
  - {{gtClass:KGFileUiControlConnector}} - Exchanges UI-control envelopes through the default filesystem spool.
  - {{gtClass:KGTcpUiControlConnector}} - Exchanges UI-control envelopes through loopback TCP NDJSON.
  - {{gtClass:KGUiControlService}} - Validates connector-independent live scene requests, waits, batches, Scripter actions, and evaluation.
  - {{gtClass:KGUiSceneGraph}} - Enumerates instantiated Bloc scene nodes, records state, and maintains stable run-local handles.
  - {{gtClass:KGExistingSpaceScripter}} - Attaches Scripter to an existing Bloc space without reparenting its elements.
  - {{gtClass:KGGuiWorldCloseEventHandler}} - Keeps native close requests inside the managed GUI world until restorable state is saved or discarded.
  - {{gtClass:KGGuiTabAddedEventHandler}} - Marks a GUI run as changed when it gains restorable tool state.
  - {{gtClass:KGTestTool}} - Runs project SUnit tests with structured failure and error diagnostics.
  - {{gtClass:KGBuildMap}} - Models a timestamped host inventory and builds aggregate and relationship Mondrian views.
  - {{gtClass:KGBuildMapNode}} - Represents one clickable build entity with size, status, metadata, and relationship views.
  - {{gtClass:KGBuildMapTool}} - Opens disposable build-map sessions and renders overview and full-graph PNGs.
  - {{gtClass:KGToolRunner}} - Dispatches structured CLI requests and normalizes image-tool responses.
  - {{gtClass:KGCodeSearchTool}} - Searches loaded code and returns exact class or method definitions.
  - {{gtClass:KGLepiterTool}} - Searches loaded Lepiter databases and exports pages as Markdown.
  - {{gtClass:KGEvaluationTool}} - Evaluates Smalltalk expressions with structured errors and optional profiling.
- Tests
  - {{gtClass:KlibGenGtTest}} - Basic project smoke tests.
  - {{gtClass:KGMethodArgCheckerTest}} - Tests for the method argument checker example.
  - {{gtClass:KGHtmlParserTest}} - Tests for the simplified HTML and legacy code-block parsers.
  - {{gtClass:KGLegacyPostTransformerTest}} - Tests for the legacy post transformation rules.
  - {{gtClass:KGCheckTypePragmasTest}} - Tests for the documentation type checker.
  - {{gtClass:KGSQLite3ExamplesTest}} - Exercises SQLite3 diagnostics and round trips through the project baseline.
  - {{gtClass:KGKotlinParserTest}} - Tests for the Kotlin sample parser and fixture comparison.
  - {{gtClass:KGJsonModelsTest}} - Tests generated v0.2 JSON validation, round trips, and registry dispatch.
  - {{gtClass:KGToolsTest}} - Tests structured code search, Lepiter access, evaluation, and profiling.
"
Class {
	#name : 'KlibGenGt',
	#superclass : 'Object',
	#category : 'KlibGenGt-Core',
	#package : 'KlibGenGt-Core'
}

{ #category : 'accessing' }
KlibGenGt class >> classHierarchyClasses [
	<return: #OrderedCollection>
	| packageClasses classes |
	packageClasses := RPackageOrganizer default packages
		select: [ :each | each name asString beginsWith: 'KlibGenGt-' ]
		thenCollect: [ :each | each definedClasses ].
	classes := (packageClasses flattened , self classHierarchyRootClasses)
		asSet asOrderedCollection.
	^ classes sorted: [ :a :b | a name < b name ]
]

{ #category : 'accessing' }
KlibGenGt class >> classHierarchyChildrenFor: aClass in: classes [
	<arg: #aClass type: #ClassDescription>
	<arg: #classes type: #(OrderedCollection | Array | Set)>
	<return: #OrderedCollection>
	^ classes select: [ :each |
		each ~~ aClass and: [
			(self classHierarchyParentOf: each in: classes) = aClass ] ]
]

{ #category : 'examples' }
KlibGenGt class >> classHierarchyMondrian [
	<gtExample>
	<return: #GtMondrian>
	<return: #GtMondrian>
	| classes mondrian |
	classes := self classHierarchyClasses.
	mondrian := GtMondrian new.
	mondrian nodes
		stencil: [ :aClass | self classHierarchyNodeElementFor: aClass ];
		with: classes.
	mondrian edges
		fromRightCenter;
		toLeftCenter;
		stencil: [ :aClass |
			BlLineElement new
				zIndex: -1;
				border: (BlBorder paint: (Color veryVeryLightGray alpha: 0.8) width: 1) ];
		connectToAll: [ :aClass | self classHierarchyChildrenFor: aClass in: classes ].
	mondrian layout horizontalTree
		levelDistance: 45;
		nodeDistance: 8.
	^ mondrian
]

{ #category : 'private - visualizations' }
KlibGenGt class >> classHierarchyNodeElementFor: aClass [
	<arg: #aClass type: #ClassDescription>
	<return: #BlElement>
	| isRoot background |
	isRoot := self classHierarchyRootClasses includes: aClass.
	background := isRoot
		ifTrue: [ Color veryVeryLightGray ]
		ifFalse: [ Color paleBlue muchLighter ].
	^ BlTextElement new
		text: aClass name asRopedText;
		padding: (BlInsets top: 5 right: 8 bottom: 5 left: 8);
		background: background;
		border: (BlBorder paint: (isRoot ifTrue: [ Color gray ] ifFalse: [ Color blue muchLighter ]) width: 1);
		constraintsDo: [ :c |
			c horizontal fitContent.
			c vertical fitContent ];
		aptitude: (BrGlamorousWithExplicitTooltipAptitude text: aClass package name)
]

{ #category : 'accessing' }
KlibGenGt class >> classHierarchyParentOf: aClass in: classes [
	<arg: #aClass type: #ClassDescription>
	<arg: #classes type: #(OrderedCollection | Array | Set)>
	<return: #(ClassDescription?)>
	| superclass |
	superclass := aClass superclass.
	[ superclass notNil ] whileTrue: [
		(classes includes: superclass) ifTrue: [ ^ superclass ].
		superclass := superclass superclass ].
	^ nil
]

{ #category : 'accessing' }
KlibGenGt class >> classHierarchyRootClasses [
	<return: #Array>
	^ { Object. PP2CompositeNode. TestCase }
]

{ #category : 'exporting' }
KlibGenGt class >> exportClassHierarchyPngTo: aFileReference [
	<arg: #aFileReference type: #(FileReference | String)>
	<return: #LeExampleToPngExporter>
	^ LeExampleToPngExporter new
		example: (KlibGenGt class >> #classHierarchyMondrian) gtExample;
		fileReference: aFileReference asFileReference;
		previewSelector: #gtLiveFor:;
		width: 900;
		height: 360;
		withoutScripter;
		export
]

{ #category : 'accessing' }
KlibGenGt class >> projectName [
	<return: #String>
    ^ 'KlibGenGt'
]

{ #category : 'accessing' }
KlibGenGt class >> sampleGreeting [
	<return: #String>
    ^ 'Hello from ', self projectName
]
