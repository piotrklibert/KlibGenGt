"
A read-only graph of recipes, resolved steps, artifacts, references, workspaces, and staging areas.

- Slots
  - `inventory` (`#KGInventoryV2`, `accessing`) - Typed host `klibgen.inventory/2` record.
  - `nodesById` (`#(Dictionary<String, KGBuildMapNode>)`, `accessing`) - Stable node lookup.
  - `kindFilter` (`#(String?)`, `filtering`) - Optional entity-kind filter.
  - `statusFilter` (`#(String?)`, `filtering`) - Optional state filter.
- Public API
  - {{gtMethod:KGBuildMap class>>#fromFile:}}
    Load a versioned inventory from JSON.
  - {{gtMethod:KGBuildMap class>>#fromDictionary:}}
    Create a map from decoded inventory.
  - {{gtMethod:KGBuildMap class>>#fromInventory:}}
    Create a map from a validated typed inventory.
  - {{gtMethod:KGBuildMap>>#overviewMondrian}}
    Build the storage overview.
  - {{gtMethod:KGBuildMap>>#graphMondrian}}
    Build the recipe-derived relationship graph.
  - {{gtMethod:KGBuildMap>>#filteredByKind:status:}}
    Answer a map with explicit generic filters.
"
Class {
	#name : 'KGBuildMap',
	#superclass : 'Object',
	#instVars : [
		'inventory',
		'nodesById',
		'kindFilter',
		'statusFilter'
	],
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'instance creation' }
KGBuildMap class >> fromDictionary: aDictionary [ <arg: #aDictionary type: #(Dictionary<String, Any>)> <return: #KGBuildMap> ^ self fromInventory: (KGInventoryV2 fromDictionary: aDictionary)
]

{ #category : 'instance creation' }
KGBuildMap class >> fromFile: aFileReference [ <arg: #aFileReference type: #(FileReference | String)> <return: #KGBuildMap> ^ self fromInventory: (KGInventoryV2 fromJson: aFileReference asFileReference contents)
]

{ #category : 'instance creation' }
KGBuildMap class >> fromInventory: anInventory [ <arg: #anInventory type: #KGInventoryV2> <return: #KGBuildMap> ^ self new initializeFromInventory: anInventory
]

{ #category : 'private - visualization' }
KGBuildMap >> backgroundForKind: kind [
	<arg: #kind type: #String> <return: #Color>
	^ { 'target' -> Color lightCyan. 'step' -> Color veryVeryLightGray. 'artifact' -> Color paleBlue. 'reference' -> Color lightYellow. 'workspace' -> Color paleGreen. 'staging' -> Color paleOrange } asDictionary at: kind ifAbsent: [ Color white ]
]

{ #category : 'private - visualization' }
KGBuildMap >> edgeElement [
	<return: #BlLineElement>
	^ BlLineElement new zIndex: -1; border: self normalEdgeBorder; when: BlMouseEnterEvent do: [ :event | event currentTarget zIndex: 1; border: self highlightedEdgeBorder. event currentTarget graph connectedNodes do: [ :element | element border: self highlightedNodeBorder ] ]; when: BlMouseLeaveEvent do: [ :event | event currentTarget zIndex: -1; border: self normalEdgeBorder. event currentTarget graph connectedNodes do: [ :element | element border: (self nodeBorderFor: element graph model) ] ]
]

{ #category : 'accessing' }
KGBuildMap >> edges [ <return: #(Array<KGJsonInventoryEdgeRecord>)> ^ inventory edges
]

{ #category : 'private - filtering' }
KGBuildMap >> filterMaps [
	<return: #(OrderedCollection<(Association<String, KGBuildMap>)>)>
	| maps | maps := OrderedCollection with: 'All nodes' -> self.
	(self nodes collect: #kind) asSet asArray sorted do: [ :each | maps add: ('Kind: ', each) -> (self filteredByKind: each status: nil) ].
	(self nodes collect: #status) asSet asArray sorted do: [ :each | maps add: ('Status: ', each) -> (self filteredByKind: nil status: each) ]. ^ maps
]

{ #category : 'filtering' }
KGBuildMap >> filteredByKind: aKind status: aStatus [
	<arg: #aKind type: #(String?)> <arg: #aStatus type: #(String?)> <return: #KGBuildMap>
	^ (self class fromInventory: inventory) kindFilter: aKind; statusFilter: aStatus; yourself
]

{ #category : 'accessing' }
KGBuildMap >> generatedAt [ <return: #String> ^ inventory generatedAt
]

{ #category : 'visualization' }
KGBuildMap >> graphMondrian [ <return: #GtMondrian> ^ self paintGraphOn: GtMondrian new
]

{ #category : 'views' }
KGBuildMap >> gtFiltersFor: aView [ <gtView> <arg: #aView type: #GtPhlowView> <return: #GtPhlowView> ^ aView columnedList title: 'Filters'; priority: 8; items: [ self filterMaps ]; column: 'Filter' text: #key; column: 'Nodes' text: [ :each | each value visibleNodes size ]; send: #value
]

{ #category : 'views' }
KGBuildMap >> gtGraphFor: aView [ <gtView> <arg: #aView type: #GtPhlowView> <return: #GtPhlowView> ^ aView mondrian title: 'Graph'; priority: 5; painting: [ :mondrian | self paintGraphOn: mondrian ]
]

{ #category : 'views' }
KGBuildMap >> gtInventoryFor: aView [ <gtView> <arg: #aView type: #GtPhlowView> <return: #GtPhlowView> ^ aView columnedList title: 'Inventory'; priority: 10; items: [ self visibleNodes ]; column: 'Kind' text: #kind; column: 'Label' text: #label; column: 'Status' text: #status; column: 'Logical' text: [ :each | self humanBytes: each logicalBytes ]; column: 'Allocated' text: [ :each | self humanBytes: each allocatedBytes ]
]

{ #category : 'views' }
KGBuildMap >> gtOverviewFor: aView [ <gtView> <arg: #aView type: #GtPhlowView> <return: #GtPhlowView> ^ aView mondrian title: 'Overview'; priority: 1; painting: [ :mondrian | self paintOverviewOn: mondrian ]
]

{ #category : 'private - visualization' }
KGBuildMap >> highlightedEdgeBorder [ <return: #BlBorder> ^ BlBorder paint: (Color blue alpha: 0.9) width: 4
]

{ #category : 'private - visualization' }
KGBuildMap >> highlightedNodeBorder [ <return: #BlBorder> ^ BlBorder paint: (Color blue alpha: 0.9) width: 4
]

{ #category : 'accessing' }
KGBuildMap >> humanBytes: byteCount [
	<arg: #byteCount type: #Integer> <return: #String>
	| amount units index | amount := byteCount asFloat. units := #('B' 'KiB' 'MiB' 'GiB' 'TiB'). index := 1.
	[ amount >= 1024 and: [ index < units size ] ] whileTrue: [ amount := amount / 1024. index := index + 1 ].
	^ (index = 1 ifTrue: [ byteCount asString ] ifFalse: [ amount printShowingDecimalPlaces: 1 ]), ' ', (units at: index)
]

{ #category : 'initialization' }
KGBuildMap >> initializeFromInventory: anInventory [
	<arg: #anInventory type: #KGInventoryV2> <return: #KGBuildMap>
	inventory := anInventory. nodesById := Dictionary new.
	anInventory nodes do: [ :record | | node | node := KGBuildMapNode from: record in: self. nodesById at: node id put: node ]. ^ self
]

{ #category : 'accessing' }
KGBuildMap >> inventory [ <return: #KGInventoryV2> ^ inventory
]

{ #category : 'filtering' }
KGBuildMap >> kindFilter: aKind [ <arg: #aKind type: #(String?)> <return: #KGBuildMap> kindFilter := aKind
]

{ #category : 'accessing' }
KGBuildMap >> nodeAt: nodeId [ <arg: #nodeId type: #String> <return: #(KGBuildMapNode?)> ^ nodesById at: nodeId ifAbsent: [ nil ]
]

{ #category : 'private - visualization' }
KGBuildMap >> nodeBorderFor: node [
	<arg: #node type: #KGBuildMapNode> <return: #BlBorder>
	| color | color := (#('failed' 'invalid' 'malformed' 'conflicted' 'abnormal') includes: node status) ifTrue: [ Color red ] ifFalse: [ (#('current' 'active' 'resolved' 'verified' 'ready' 'saved' 'promoted') includes: node status) ifTrue: [ Color green muchDarker ] ifFalse: [ Color gray ] ]. ^ BlBorder paint: color width: 2
]

{ #category : 'private - visualization' }
KGBuildMap >> nodeElementFor: node [
	<arg: #node type: #KGBuildMapNode> <return: #BlElement>
	| padding | padding := (((node allocatedBytes + 1) log / 2) max: 6) min: 22.
	^ BlTextElement new text: node label asRopedText; padding: (BlInsets all: padding); background: (self backgroundForKind: node kind); border: (self nodeBorderFor: node); constraintsDo: [ :constraints | constraints horizontal fitContent. constraints vertical fitContent ]; when: BlClickEvent do: [ :event | event consumed: true. event currentTarget phlow spawnObject: node ]; aptitude: (BrGlamorousWithExplicitTooltipAptitude content: [ self nodeTooltipElementFor: node ])
]

{ #category : 'private - visualization' }
KGBuildMap >> nodeTooltipElementFor: node [
	<arg: #node type: #KGBuildMapNode> <return: #BlElement>
	^ BrVerticalPane new fitContent; alignCenterLeft; padding: (BlInsets all: 8); addChildren: {
		BrLabel new aptitude: BrGlamorousLabelAptitude; text: node label.
		BrLabel new aptitude: BrGlamorousLabelAptitude; text: 'Status: ', node status.
		BrLabel new aptitude: BrGlamorousLabelAptitude; text: (self humanBytes: node logicalBytes), ' logical / ', (self humanBytes: node allocatedBytes), ' allocated' }
]

{ #category : 'accessing' }
KGBuildMap >> nodes [ <return: #(Array<KGBuildMapNode>)> ^ nodesById values asArray sorted: [ :a :b | a id < b id ]
]

{ #category : 'private - visualization' }
KGBuildMap >> normalEdgeBorder [ <return: #BlBorder> ^ BlBorder paint: (Color gray alpha: 0.35) width: 2
]

{ #category : 'visualization' }
KGBuildMap >> overviewMondrian [ <return: #GtMondrian> ^ self paintOverviewOn: GtMondrian new
]

{ #category : 'private - visualization' }
KGBuildMap >> paintGraphOn: mondrian [
	<arg: #mondrian type: #GtMondrian> <return: #GtMondrian>
	| visible ids | visible := self visibleNodes. ids := (visible collect: #id) asSet.
	mondrian nodes stencil: [ :node | self nodeElementFor: node ]; with: visible.
	mondrian edges fromRightCenter; toLeftCenter; stencil: [ :node | self edgeElement ]; connectToAll: [ :node | (self targetsFrom: node) select: [ :target | ids includes: target id ] ].
	mondrian layout horizontalDominanceTree nodeDistance: 12; levelDistance: 55. ^ mondrian
]

{ #category : 'private - visualization' }
KGBuildMap >> paintOverviewOn: mondrian [
	<arg: #mondrian type: #GtMondrian> <return: #GtMondrian>
	mondrian nodes stencil: [ :summary | BlTextElement new text: ((summary at: 'kind'), ' — ', (summary at: 'count') asString, ' — ', (self humanBytes: (summary at: 'allocatedBytes')), ' allocated') asRopedText; padding: (BlInsets all: 12); background: (self backgroundForKind: (summary at: 'kind')); border: (BlBorder paint: Color gray width: 1) ]; with: self summaryRecords.
	mondrian layout rectanglePack. ^ mondrian
]

{ #category : 'printing' }
KGBuildMap >> printOn: aStream [ <arg: #aStream type: #Stream> <return: #KGBuildMap> aStream nextPutAll: 'Build map ('; print: self visibleNodes size; nextPutAll: ' nodes, '; nextPutAll: self generatedAt; nextPut: $)
]

{ #category : 'filtering' }
KGBuildMap >> statusFilter: aStatus [ <arg: #aStatus type: #(String?)> <return: #KGBuildMap> statusFilter := aStatus
]

{ #category : 'private - visualization' }
KGBuildMap >> summaryRecords [
	<return: #(Array<(Dictionary<String, Any>)>)>
	| groups | groups := self nodes groupedBy: #kind.
	^ (groups associations collect: [ :association | Dictionary new at: 'kind' put: association key; at: 'count' put: association value size; at: 'logicalBytes' put: (association value sum: #logicalBytes); at: 'allocatedBytes' put: (association value sum: #allocatedBytes); yourself ]) sorted: [ :a :b | (a at: 'kind') < (b at: 'kind') ]
]

{ #category : 'private - visualization' }
KGBuildMap >> targetsFrom: node [
	<arg: #node type: #KGBuildMapNode> <return: #(OrderedCollection<KGBuildMapNode>)>
	^ ((self edges select: [ :edge | edge source = node id ]) collect: [ :edge | self nodeAt: edge target ]) reject: #isNil
]

{ #category : 'filtering' }
KGBuildMap >> visibleNodes [
	<return: #(Array<KGBuildMapNode>)>
	^ self nodes select: [ :node | (kindFilter isNil or: [ node kind = kindFilter ]) and: [ statusFilter isNil or: [ node status = statusFilter ] ] ]
]
