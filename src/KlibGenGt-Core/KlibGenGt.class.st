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
  - {{gtClass:KGGuiSessionHooks}} - Emits GUI lifecycle and exact-repository Iceberg commit events for host-side promotion.
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
