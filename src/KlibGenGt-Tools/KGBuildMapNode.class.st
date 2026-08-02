"A typed node in a host-generated build inventory.

- Slots
  - `record` (`#(Dictionary<String, Any>)`, `accessing`) - Versioned JSON-compatible node data produced by the host collector.
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
	<arg: #aRecord type: #(Dictionary<String, Any>)>
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
	^ record at: 'allocatedBytes' ifAbsent: [ 0 ]
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
	^ record at: 'id'
]

{ #category : 'accessing' }
KGBuildMapNode >> kind [
	<return: #String>
	^ record at: 'kind'
]

{ #category : 'accessing' }
KGBuildMapNode >> label [
	<return: #String>
	^ record at: 'label'
]

{ #category : 'accessing' }
KGBuildMapNode >> logicalBytes [
	<return: #Integer>
	^ record at: 'logicalBytes' ifAbsent: [ 0 ]
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
	<return: #(Dictionary<String, Any>)>
	^ record
]

{ #category : 'accessing' }
KGBuildMapNode >> record: aRecord [
	<arg: #aRecord type: #(Dictionary<String, Any>)>
	<return: #KGBuildMapNode>
	record := aRecord
]

{ #category : 'accessing' }
KGBuildMapNode >> relationships [
	<return: #(OrderedCollection<(Dictionary<String, Any>)>)>
	^ buildMap edges select: [ :each |
		(each at: 'source') = self id or: [ (each at: 'target') = self id ] ]
]

{ #category : 'accessing' }
KGBuildMapNode >> status [
	<return: #String>
	^ record at: 'status'
]

{ #category : 'views' }
KGBuildMapNode >> gtCharacteristicsFor: aView [
	<gtView>
	<arg: #aView type: #GtPhlowView>
	<return: #GtPhlowView>
	^ aView textEditor
		title: 'Characteristics';
		priority: 20;
		text: [ STONJSON toStringPretty: (record at: 'characteristics') ]
]

{ #category : 'views' }
KGBuildMapNode >> gtComponentsFor: aView [
	<gtView>
	<arg: #aView type: #GtPhlowView>
	<return: #GtPhlowView>
	^ aView columnedList
		title: 'Components';
		priority: 10;
		items: [ record at: 'components' ifAbsent: [ #() ] ];
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
		column: 'Kind' text: [ :each | each at: 'kind' ];
		column: 'From' text: [ :each | each at: 'source' ];
		column: 'To' text: [ :each | each at: 'target' ]
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
			'Files' -> (record at: 'fileCount' ifAbsent: [ 0 ]).
			'Path' -> (record at: 'path' ifAbsent: [ '' ]) } ];
		column: 'Characteristic' text: #key;
		column: 'Value' text: [ :each | each value asString ]
]
