"A typed node in a host-generated build inventory.

- Slots
  - `record` (`#KGJsonInventoryNodeRecord`, `accessing`) - Typed node data produced by the host collector.
  - `buildMap` (`#KGBuildMap`, `accessing`) - Owning map used to resolve relationships.
- Public API
  - {{gtMethod:KGBuildMapNode class>>#from:in:}}
    Create a node backed by one inventory record and its owning map.
  - {{gtMethod:KGBuildMapNode>>#id}}
    Answer the stable inventory identifier.
  - {{gtMethod:KGBuildMapNode>>#kind}}
    Answer the logical build-entity kind.
  - {{gtMethod:KGBuildMapNode>>#status}}
    Answer the host-computed status.
  - {{gtMethod:KGBuildMapNode>>#relationships}}
    Answer every inventory edge touching this node.
"
Class {
	#name : 'KGBuildMapNode',
	#superclass : 'Object',
	#instVars : [
		'record',
		'buildMap'
	],
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'instance creation' }
KGBuildMapNode class >> from: aRecord in: aBuildMap [
	<arg: #aRecord type: #KGJsonInventoryNodeRecord>
	<arg: #aBuildMap type: #KGBuildMap>
	<return: #KGBuildMapNode>
	^ self new
		record: aRecord;
		buildMap: aBuildMap;
		yourself
]

{ #category : 'accessing' }
KGBuildMapNode >> allocatedBytes [
	<return: #Integer>
	^ record allocatedBytes
]

{ #category : 'accessing' }
KGBuildMapNode >> buildMap: aBuildMap [
	<arg: #aBuildMap type: #KGBuildMap>
	<return: #KGBuildMapNode>
	buildMap := aBuildMap
]

{ #category : 'accessing' }
KGBuildMapNode >> id [
	<return: #String>
	^ record id
]

{ #category : 'accessing' }
KGBuildMapNode >> kind [
	<return: #String>
	^ record kind
]

{ #category : 'accessing' }
KGBuildMapNode >> label [
	<return: #String>
	^ record label
]

{ #category : 'accessing' }
KGBuildMapNode >> logicalBytes [
	<return: #Integer>
	^ record logicalBytes
]

{ #category : 'printing' }
KGBuildMapNode >> printOn: aStream [
	<arg: #aStream type: #Stream>
	<return: #KGBuildMapNode>
	aStream
		nextPutAll: self kind;
		nextPutAll: ': ';
		nextPutAll: self label;
		nextPutAll: ' (';
		nextPutAll: self status;
		nextPut: $)
]

{ #category : 'accessing' }
KGBuildMapNode >> record [
	<return: #KGJsonInventoryNodeRecord>
	^ record
]

{ #category : 'accessing' }
KGBuildMapNode >> record: aRecord [
	<arg: #aRecord type: #KGJsonInventoryNodeRecord>
	<return: #KGBuildMapNode>
	record := aRecord
]

{ #category : 'accessing' }
KGBuildMapNode >> relationships [
	<return: #(Array<KGJsonInventoryEdgeRecord>)>
	^ buildMap edges select: [ :each |
		each source = self id or: [ each target = self id ] ]
]

{ #category : 'accessing' }
KGBuildMapNode >> status [
	<return: #String>
	^ record status
]

{ #category : 'views' }
KGBuildMapNode >> gtCharacteristicsFor: aView [
	<gtView>
	<arg: #aView type: #GtPhlowView>
	<return: #GtPhlowView>
	^ aView textEditor
		title: 'Characteristics';
		priority: 20;
		text: [ STONJSON toStringPretty: record characteristics ]
]

{ #category : 'views' }
KGBuildMapNode >> gtComponentsFor: aView [
	<gtView>
	<arg: #aView type: #GtPhlowView>
	<return: #GtPhlowView>
	^ aView columnedList
		title: 'Components';
		priority: 10;
		items: [ record asDictionary at: 'components' ifAbsent: [ #() ] ];
		column: 'Name' text: [ :each | each at: 'name' ];
		column: 'Logical' text: [ :each | buildMap humanBytes: (each at: 'logicalBytes') ];
		column: 'Allocated' text: [ :each | buildMap humanBytes: (each at: 'allocatedBytes') ];
		column: 'Files' text: [ :each | each at: 'fileCount' ];
		column: 'Path' text: [ :each | each at: 'path' ]
]

{ #category : 'views' }
KGBuildMapNode >> gtRelationshipsFor: aView [
	<gtView>
	<arg: #aView type: #GtPhlowView>
	<return: #GtPhlowView>
	^ aView columnedList
		title: 'Relationships';
		priority: 15;
		items: [ self relationships ];
		column: 'Kind' text: #kind;
		column: 'From' text: #source;
		column: 'To' text: #target
]

{ #category : 'views' }
KGBuildMapNode >> gtSummaryFor: aView [
	<gtView>
	<arg: #aView type: #GtPhlowView>
	<return: #GtPhlowView>
	^ aView columnedList
		title: 'Summary';
		priority: 1;
		items: [ {
			'Kind' -> self kind.
			'Status' -> self status.
			'Logical size' -> (buildMap humanBytes: self logicalBytes).
			'Allocated size' -> (buildMap humanBytes: self allocatedBytes).
			'Files' -> record fileCount.
			'Path' -> (record path ifNil: [ '' ]) } ];
		column: 'Characteristic' text: #key;
		column: 'Value' text: [ :each | each value asString ]
]
