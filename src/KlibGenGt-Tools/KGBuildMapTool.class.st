"Registered image-side entry point for build-map PNG export.

- Slots
  - none
- Public API
  - {{gtMethod:KGBuildMapTool>>#exportPngs:}}
    Render overview and full-graph PNG files for a structured image-tool request.
"
Class {
	#name : 'KGBuildMapTool',
	#superclass : 'Object',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

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
