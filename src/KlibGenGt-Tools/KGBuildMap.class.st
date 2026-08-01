"A read-only snapshot of committed build definitions and generated build state.

- Slots
  - `inventory` (`#(Dictionary<String, Any>)`, `accessing`) - Versioned host inventory including metrics, nodes, edges, and warnings.
  - `nodesById` (`#(Dictionary<String, KGBuildMapNode>)`, `accessing`) - Stable node lookup used by graph relationships.
  - `contextFilter` (`#(String?)`, `filtering`) - Optional context included in graph presentations.
  - `kindFilter` (`#(String?)`, `filtering`) - Optional logical entity kind included in graph presentations.
  - `statusFilter` (`#(String?)`, `filtering`) - Optional status included in graph presentations.
- Public API
  - {{gtMethod:KGBuildMap class>>#fromFile:}}
    Load a versioned build inventory from JSON.
  - {{gtMethod:KGBuildMap class>>#fromDictionary:}}
    Create a map from an already decoded inventory.
  - {{gtMethod:KGBuildMap>>#overviewMondrian}}
    Build the aggregate storage overview.
  - {{gtMethod:KGBuildMap>>#graphMondrian}}
    Build the filtered relationship graph.
  - {{gtMethod:KGBuildMap>>#filteredByContext:kind:status:}}
    Answer a new map sharing the inventory with explicit filters.
"
Class {
	#name : 'KGBuildMap',
	#superclass : 'Object',
	#instVars : [
		'inventory',
		'nodesById',
		'contextFilter',
		'kindFilter',
		'statusFilter'
	],
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'instance creation' }
KGBuildMap class >> fromDictionary: aDictionary [
	<arg: #aDictionary type: #(Dictionary<String, Any>)>
	<return: #KGBuildMap>
	^ self new initializeFromDictionary: aDictionary
]

{ #category : 'instance creation' }
KGBuildMap class >> fromFile: aFileReference [
	<arg: #aFileReference type: #(FileReference | String)>
	<return: #KGBuildMap>
	^ self fromDictionary: (STONJSON fromString: aFileReference asFileReference contents)
]

{ #category : 'private - visualization' }
KGBuildMap >> backgroundForKind: kind [
	<arg: #kind type: #String>
	<return: #Color>
	^ {
		'artifact' -> Color paleBlue.
		'run' -> Color paleGreen.
		'snapshot' -> Color paleOrange.
		'context' -> Color veryVeryLightGray.
		'layer' -> Color lightCyan.
		'attempt' -> Color lightRed.
		'pin' -> Color lightYellow } asDictionary
		at: kind ifAbsent: [ Color white ]
]

{ #category : 'private - visualization' }
KGBuildMap >> edgeElement [
	<return: #BlLineElement>
	^ BlLineElement new
		zIndex: -1;
		border: self normalEdgeBorder;
		when: BlMouseEnterEvent do: [ :event |
			event currentTarget
				zIndex: 1;
				border: self highlightedEdgeBorder.
		event currentTarget graph connectedNodes do: [ :connectedNode |
				connectedNode border: self highlightedNodeBorder ] ];
		when: BlMouseLeaveEvent do: [ :event |
			event currentTarget
				zIndex: -1;
				border: self normalEdgeBorder.
		event currentTarget graph connectedNodes do: [ :connectedNode |
				connectedNode border: (self nodeBorderFor: connectedNode graph model) ] ]
]

{ #category : 'private - visualization' }
KGBuildMap >> highlightedEdgeBorder [
	<return: #BlBorder>
	^ BlBorder paint: (Color blue alpha: 0.9) width: 4
]

{ #category : 'private - visualization' }
KGBuildMap >> highlightedNodeBorder [
	<return: #BlBorder>
	^ BlBorder paint: (Color blue alpha: 0.9) width: 4
]

{ #category : 'accessing' }
KGBuildMap >> contexts [
	<return: #(Array<String>)>
	^ ((self nodes collect: #contextId) reject: #isNil) asSet asArray sorted
]

{ #category : 'accessing' }
KGBuildMap >> edges [
	<return: #(OrderedCollection<(Dictionary<String, Any>)>)>
	^ inventory at: 'edges'
]

{ #category : 'filtering' }
KGBuildMap >> filteredByContext: aContext kind: aKind status: aStatus [
	<arg: #aContext type: #(String?)>
	<arg: #aKind type: #(String?)>
	<arg: #aStatus type: #(String?)>
	<return: #KGBuildMap>
	^ (self class fromDictionary: inventory)
		contextFilter: aContext;
		kindFilter: aKind;
		statusFilter: aStatus;
		yourself
]

{ #category : 'accessing' }
KGBuildMap >> generatedAt [
	<return: #String>
	^ inventory at: 'generatedAt'
]

{ #category : 'visualization' }
KGBuildMap >> graphMondrian [
	<return: #GtMondrian>
	^ self paintGraphOn: GtMondrian new
]

{ #category : 'views' }
KGBuildMap >> gtFiltersFor: aView [
	<gtView>
	<arg: #aView type: #GtPhlowView>
	<return: #GtPhlowView>
	^ aView columnedList
		title: 'Filters';
		priority: 8;
		items: [ self filterMaps ];
		column: 'Filter' text: [ :each | each key ];
		column: 'Nodes' text: [ :each | each value visibleNodes size ];
		send: #value
]

{ #category : 'views' }
KGBuildMap >> gtGraphFor: aView [
	<gtView>
	<arg: #aView type: #GtPhlowView>
	<return: #GtPhlowView>
	^ aView mondrian
		title: 'Graph';
		priority: 5;
		painting: [ :mondrian | self paintGraphOn: mondrian ]
]

{ #category : 'views' }
KGBuildMap >> gtInventoryFor: aView [
	<gtView>
	<arg: #aView type: #GtPhlowView>
	<return: #GtPhlowView>
	^ aView columnedList
		title: 'Inventory';
		priority: 10;
		items: [ self visibleNodes ];
		column: 'Kind' text: #kind;
		column: 'Label' text: #label;
		column: 'Status' text: #status;
		column: 'Context' text: [ :each | each contextId ifNil: [ '' ] ];
		column: 'Logical' text: [ :each | self humanBytes: each logicalBytes ];
		column: 'Allocated' text: [ :each | self humanBytes: each allocatedBytes ]
]

{ #category : 'views' }
KGBuildMap >> gtOverviewFor: aView [
	<gtView>
	<arg: #aView type: #GtPhlowView>
	<return: #GtPhlowView>
	^ aView mondrian
		title: 'Overview';
		priority: 1;
		painting: [ :mondrian | self paintOverviewOn: mondrian ]
]

{ #category : 'accessing' }
KGBuildMap >> humanBytes: byteCount [
	<arg: #byteCount type: #Integer>
	<return: #String>
	| amount units index |
	amount := byteCount asFloat.
	units := #('B' 'KiB' 'MiB' 'GiB' 'TiB').
	index := 1.
	[ amount >= 1024 and: [ index < units size ] ] whileTrue: [
		amount := amount / 1024.
		index := index + 1 ].
	^ (index = 1
		ifTrue: [ byteCount asString ]
		ifFalse: [ amount printShowingDecimalPlaces: 1 ]), ' ', (units at: index)
]

{ #category : 'initialization' }
KGBuildMap >> initializeFromDictionary: aDictionary [
	<arg: #aDictionary type: #(Dictionary<String, Any>)>
	<return: #KGBuildMap>
	(aDictionary at: 'schemaVersion') = 1 ifFalse: [ self error: 'unsupported build map schema' ].
	inventory := aDictionary.
	nodesById := Dictionary new.
	(aDictionary at: 'nodes') do: [ :each |
		| node |
		node := KGBuildMapNode from: each in: self.
		nodesById at: node id put: node ].
	^ self
]

{ #category : 'accessing' }
KGBuildMap >> inventory [
	<return: #(Dictionary<String, Any>)>
	^ inventory
]

{ #category : 'filtering' }
KGBuildMap >> contextFilter: aContext [
	<arg: #aContext type: #(String?)>
	<return: #KGBuildMap>
	contextFilter := aContext
]

{ #category : 'filtering' }
KGBuildMap >> kindFilter: aKind [
	<arg: #aKind type: #(String?)>
	<return: #KGBuildMap>
	kindFilter := aKind
]

{ #category : 'filtering' }
KGBuildMap >> statusFilter: aStatus [
	<arg: #aStatus type: #(String?)>
	<return: #KGBuildMap>
	statusFilter := aStatus
]

{ #category : 'private - filtering' }
KGBuildMap >> filterMaps [
	<return: #(OrderedCollection<(Association<String, KGBuildMap>)>)>
	| maps |
	maps := OrderedCollection with: 'All nodes' -> self.
	self contexts do: [ :each |
		maps add: ('Context: ', each) -> (self filteredByContext: each kind: nil status: nil) ].
	(self nodes collect: #kind) asSet asArray sorted do: [ :each |
		maps add: ('Kind: ', each) -> (self filteredByContext: nil kind: each status: nil) ].
	(self nodes collect: #status) asSet asArray sorted do: [ :each |
		maps add: ('Status: ', each) -> (self filteredByContext: nil kind: nil status: each) ].
	^ maps
]

{ #category : 'accessing' }
KGBuildMap >> nodeAt: nodeId [
	<arg: #nodeId type: #String>
	<return: #(KGBuildMapNode?)>
	^ nodesById at: nodeId ifAbsent: [ nil ]
]

{ #category : 'private - visualization' }
KGBuildMap >> nodeElementFor: node [
	<arg: #node type: #KGBuildMapNode>
	<return: #BlElement>
	| element padding |
	padding := (((node allocatedBytes + 1) log / 2) max: 6) min: 22.
	element := BlTextElement new
		text: node label asRopedText;
		padding: (BlInsets all: padding);
		background: (self backgroundForKind: node kind);
		border: (self nodeBorderFor: node);
		constraintsDo: [ :constraints |
			constraints horizontal fitContent.
			constraints vertical fitContent ];
		when: BlClickEvent do: [ :event |
			event consumed: true.
			event currentTarget phlow spawnObject: node ];
		aptitude: (BrGlamorousWithExplicitTooltipAptitude content: [
			self nodeTooltipElementFor: node ]).
	^ element
]

{ #category : 'private - visualization' }
KGBuildMap >> nodeBorderFor: node [
	<arg: #node type: #KGBuildMapNode>
	<return: #BlBorder>
	| borderColor |
	borderColor := (#('failed' 'broken' 'missing' 'malformed' 'unresolved' 'orphaned') includes: node status)
		ifTrue: [ Color red ]
		ifFalse: [ (#('current' 'active' 'resolved' 'valid') includes: node status)
			ifTrue: [ Color green muchDarker ]
			ifFalse: [ Color gray ] ].
	^ BlBorder paint: borderColor width: 2
]

{ #category : 'private - visualization' }
KGBuildMap >> nodeTooltipElementFor: node [
	<arg: #node type: #KGBuildMapNode>
	<return: #BlElement>
	^ BrVerticalPane new
		fitContent;
		alignCenterLeft;
		padding: (BlInsets all: 8);
		addChildren: {
			BrLabel new
				aptitude: BrGlamorousLabelAptitude;
				text: node label.
			BrLabel new
				aptitude: BrGlamorousLabelAptitude;
				text: 'Status: ', node status.
			BrLabel new
				aptitude: BrGlamorousLabelAptitude;
				text: (self humanBytes: node logicalBytes), ' logical / ',
					(self humanBytes: node allocatedBytes), ' allocated' }
]

{ #category : 'private - visualization' }
KGBuildMap >> normalEdgeBorder [
	<return: #BlBorder>
	^ BlBorder paint: (Color gray alpha: 0.35) width: 2
]

{ #category : 'accessing' }
KGBuildMap >> nodes [
	<return: #(Array<KGBuildMapNode>)>
	^ nodesById values asArray sorted: [ :a :b | a id < b id ]
]

{ #category : 'visualization' }
KGBuildMap >> overviewMondrian [
	<return: #GtMondrian>
	^ self paintOverviewOn: GtMondrian new
]

{ #category : 'private - visualization' }
KGBuildMap >> paintGraphOn: mondrian [
	<arg: #mondrian type: #GtMondrian>
	<return: #GtMondrian>
	| visible visibleIds |
	visible := self visibleNodes.
	visibleIds := (visible collect: #id) asSet.
	mondrian nodes
		stencil: [ :node | self nodeElementFor: node ];
		with: visible.
	mondrian edges
		fromRightCenter;
		toLeftCenter;
		stencil: [ :node | self edgeElement ];
		connectToAll: [ :node |
			(self targetsFrom: node) select: [ :target | visibleIds includes: target id ] ].
	mondrian layout horizontalDominanceTree
		nodeDistance: 12;
		levelDistance: 55.
	^ mondrian
]

{ #category : 'private - visualization' }
KGBuildMap >> paintOverviewOn: mondrian [
	<arg: #mondrian type: #GtMondrian>
	<return: #GtMondrian>
	| summaries |
	summaries := self overviewRecords.
	mondrian nodes
		stencil: [ :summary |
			BlTextElement new
				text: ((summary at: 'label' ifAbsent: [
					(summary at: 'kind'), ' — ',
					(summary at: 'count') asString, ' things — ',
					(self humanBytes: (summary at: 'logicalBytes')), ' logical — ',
					(self humanBytes: (summary at: 'allocatedBytes')), ' allocated' ])) asRopedText;
				padding: (BlInsets all: 12);
				background: (self backgroundForKind: (summary at: 'kind'));
				border: (BlBorder paint: Color gray width: 1) ];
		with: summaries.
	mondrian layout rectanglePack.
	^ mondrian
]

{ #category : 'private - visualization' }
KGBuildMap >> overviewRecords [
	<return: #(OrderedCollection<(Dictionary<String, Any>)>)>
	| records |
	records := OrderedCollection new.
	records add: (Dictionary new
		at: 'kind' put: 'inventory';
		at: 'label' put: 'Inventory generated ', self generatedAt;
		yourself).
	records addAll: self summaryRecords.
	records add: (Dictionary new
		at: 'kind' put: 'legend';
		at: 'label' put: 'Legend: color = kind; green border = current/valid; red = broken/missing/failed; gray = historical';
		yourself).
	^ records
]

{ #category : 'printing' }
KGBuildMap >> printOn: aStream [
	<arg: #aStream type: #Stream>
	<return: #KGBuildMap>
	aStream
		nextPutAll: 'Build map (';
		print: self visibleNodes size;
		nextPutAll: ' nodes, ';
		nextPutAll: self generatedAt;
		nextPut: $)
]

{ #category : 'private - visualization' }
KGBuildMap >> summaryRecords [
	<return: #(Array<(Dictionary<String, Any>)>)>
	| groups |
	groups := self nodes reject: [ :node | node record at: 'aggregate' ifAbsent: [ false ] ].
	groups := groups groupedBy: #kind.
	^ (groups associations collect: [ :association |
		Dictionary new
			at: 'kind' put: association key;
			at: 'count' put: association value size;
			at: 'logicalBytes' put: (association value sum: #logicalBytes);
			at: 'allocatedBytes' put: (association value sum: #allocatedBytes);
			yourself ]) sorted: [ :a :b | (a at: 'kind') < (b at: 'kind') ]
]

{ #category : 'private - visualization' }
KGBuildMap >> targetsFrom: node [
	<arg: #node type: #KGBuildMapNode>
	<return: #(OrderedCollection<KGBuildMapNode>)>
	^ ((self edges select: [ :edge | (edge at: 'source') = node id ])
		collect: [ :edge | self nodeAt: (edge at: 'target') ]) reject: #isNil
]

{ #category : 'filtering' }
KGBuildMap >> visibleNodes [
	<return: #(Array<KGBuildMapNode>)>
	^ self nodes select: [ :node |
		(contextFilter isNil or: [ node contextId isNil or: [ node contextId = contextFilter ] ])
			and: [ (kindFilter isNil or: [ node kind = kindFilter ])
				and: [ statusFilter isNil or: [ node status = statusFilter ] ] ] ]
]
