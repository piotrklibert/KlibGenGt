"Image-side entry point for build-map startup and PNG export.

- Slots
  - `CurrentMap` (`#(KGBuildMap?)`, class state, `system startup`) - Inventory prepared for one disposable visualization image.
  - `DidOpen` (`#Boolean`, class state, `system startup`) - Prevents duplicate inspector windows during startup.
- Public API
  - {{gtMethod:KGBuildMapTool class>>#prepareFromEnvironment}}
    Load the inventory named by `KLIBGEN_BUILD_MAP_PATH` and register disposable GUI startup.
  - {{gtMethod:KGBuildMapTool class>>#startUp:}}
    Open the prepared map in a GT inspector when the visualization image starts.
  - {{gtMethod:KGBuildMapTool>>#exportPngs:}}
    Render overview and full-graph PNG files for a structured image-tool request.
"
Class {
	#name : 'KGBuildMapTool',
	#superclass : 'Object',
	#classVars : [
		'CurrentMap',
		'DidOpen'
	],
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'system startup' }
KGBuildMapTool class >> prepareFromEnvironment [
	<return: #KGBuildMapTool>
	| path |
	path := Smalltalk os environment at: 'KLIBGEN_BUILD_MAP_PATH'.
	CurrentMap := KGBuildMap fromFile: path.
	DidOpen := false.
	SessionManager default
		register: (ClassSessionHandler forClassNamed: self name)
		inCategory: SessionManager default guiCategory
		atPriority: SessionManager default defaultPriority.
	^ self
]

{ #category : 'system startup' }
KGBuildMapTool class >> shutDown: isImageQuitting [
	<arg: #isImageQuitting type: #Boolean>
	<return: #KGBuildMapTool>
	isImageQuitting ifTrue: [ DidOpen := false ].
	^ self
]

{ #category : 'system startup' }
KGBuildMapTool class >> startUp: isImageStarting [
	<arg: #isImageStarting type: #Boolean>
	<return: #KGBuildMapTool>
	| world |
	(isImageStarting and: [ DidOpen ~= true and: [ CurrentMap notNil ] ]) ifFalse: [ ^ self ].
	DidOpen := true.
	world := GtWorld new.
	world objectInPager: CurrentMap.
	world removeShutdownListener; addShutdownListener.
	world extent: 1600 @ 864.
	world show.
	^ self
]

{ #category : 'exporting' }
KGBuildMapTool >> exportPngs: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| map directory overview graph graphHeight overviewFile graphFile |
	map := KGBuildMap fromFile: (aRequest at: 'inventoryPath').
	directory := (aRequest at: 'outputDirectory') asFileReference.
	directory ensureCreateDirectory.
	overviewFile := directory / 'overview.png'.
	graphFile := directory / 'graph.png'.
	((aRequest at: 'force' ifAbsent: [ false ]) not and: [
		overviewFile exists or: [ graphFile exists ] ]) ifTrue: [
		self error: 'refusing to overwrite existing build map PNG' ].
	overview := map overviewMondrian topStep root.
	graph := map graphMondrian topStep root.
	graphHeight := ((map nodes size * 48) max: 1800) min: 12000.
	LeElementToPngExporter new
		element: overview;
		fileReference: overviewFile;
		width: 1600;
		height: 1000;
		scaleFactor: 1;
		export.
	LeElementToPngExporter new
		element: graph;
		fileReference: graphFile;
		width: 3200;
		height: graphHeight;
		scaleFactor: 1;
		export.
	^ Dictionary new
		at: 'overviewPath' put: overviewFile fullName;
		at: 'graphPath' put: graphFile fullName;
		at: 'nodeCount' put: map nodes size;
		at: 'edgeCount' put: map edges size;
		yourself
]
