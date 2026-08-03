"
Inspect and resolve instantiated elements in live Bloc spaces.

- Slots
  - `handles` (`#(IdentityDictionary<BlElement, String>)`, `handles`) - Stable element-to-node mapping for this GUI run.
  - `elements` (`#(Dictionary<String, BlElement>)`, `handles`) - Reverse mapping used by exact node selectors.
  - `nextHandle` (`#Integer`, `handles`) - Monotonic node identifier counter.
- Public API
  - {{gtMethod:KGUiSceneGraph>>#spaces}}
    Answer every currently open Bloc space, preferring the managed world in client selection.
  - {{gtMethod:KGUiSceneGraph>>#tree:}}
    Return a bounded flat JSON-compatible tree including hidden instantiated elements.
  - {{gtMethod:KGUiSceneGraph>>#spacesData}}
    Return JSON-compatible identity and geometry records for every open space.
  - {{gtMethod:KGUiSceneGraph>>#query:}}
    Return node records matching the supplied exact and state selectors.
  - {{gtMethod:KGUiSceneGraph>>#resolveOne:}}
    Resolve exactly one attached element or report absence/ambiguity with candidates.
  - {{gtMethod:KGUiSceneGraph>>#elementAt:}}
    Resolve one run-local handle and reject a detached element.
"
Class {
	#name : 'KGUiSceneGraph',
	#superclass : 'Object',
	#instVars : [
		'handles',
		'elements',
		'nextHandle'
	],
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'private - inspection' }
KGUiSceneGraph >> boundedTextOf: anElement [
	| value |
	value := [
		(anElement respondsTo: #text)
			ifTrue: [ anElement text asString ]
			ifFalse: [ (anElement respondsTo: #label)
				ifTrue: [ anElement label asString ]
				ifFalse: [ '' ] ] ] on: Error do: [ '' ].
	^ value size > 500 ifTrue: [ (value first: 500) , '…' ] ifFalse: [ value ]
]

{ #category : 'private - inspection' }
KGUiSceneGraph >> boundsDataOf: anElement [
	| rectangle |
	rectangle := [ anElement bounds inSpace bounds ] on: Error do: [ 0 @ 0 extent: 0 @ 0 ].
	^ OrderedDictionary new
		at: 'x' put: rectangle left;
		at: 'y' put: rectangle top;
		at: 'width' put: rectangle width;
		at: 'height' put: rectangle height;
		yourself
]

{ #category : 'private - inspection' }
KGUiSceneGraph >> effectiveVisibilityOf: anElement [
	| current |
	current := anElement.
	[ current notNil ] whileTrue: [
		current isVisible ifFalse: [ ^ false ].
		current := current parent ].
	^ true
]

{ #category : 'public - handles' }
KGUiSceneGraph >> elementAt: aHandle [
	<arg: #aHandle type: #String>
	<return: #BlElement>
	| element |
	element := elements at: aHandle ifAbsent: [ self error: 'unknown UI node: ' , aHandle ].
	element isAttachedToSceneGraph ifFalse: [
		elements removeKey: aHandle ifAbsent: [ ].
		handles removeKey: element ifAbsent: [ ].
		self error: 'detached UI node: ' , aHandle ].
	^ element
]

{ #category : 'private - handles' }
KGUiSceneGraph >> handleFor: anElement [
	^ handles at: anElement ifAbsentPut: [
		| handle |
		handle := 'node-' , nextHandle asString.
		nextHandle := nextHandle + 1.
		elements at: handle put: anElement.
		handle ]
]

{ #category : 'initialization' }
KGUiSceneGraph >> initialize [
	super initialize.
	handles := IdentityDictionary new.
	elements := Dictionary new.
	nextHandle := 1
]

{ #category : 'private - handles' }
KGUiSceneGraph >> pruneHandles [
	(elements keys select: [ :handle | (elements at: handle) isAttachedToSceneGraph not ])
		do: [ :handle |
			| element |
			element := elements removeKey: handle.
			handles removeKey: element ifAbsent: [ ] ]
]

{ #category : 'public - querying' }
KGUiSceneGraph >> query: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| tree matches |
	tree := self tree: aRequest.
	matches := (tree at: 'nodes') select: [ :record | self record: record matches: aRequest ].
	^ OrderedDictionary new
		at: 'space' put: (tree at: 'space');
		at: 'matches' put: matches asArray;
		at: 'count' put: matches size;
		yourself
]

{ #category : 'private - querying' }
KGUiSceneGraph >> record: record matches: aRequest [
	(aRequest at: 'node' ifAbsent: [ record at: 'nodeId' ]) = (record at: 'nodeId') ifFalse: [ ^ false ].
	(aRequest at: 'class' ifAbsent: [ record at: 'class' ]) = (record at: 'class') ifFalse: [ ^ false ].
	(aRequest at: 'elementId' ifAbsent: [ record at: 'elementId' ]) = (record at: 'elementId') ifFalse: [ ^ false ].
	(aRequest includesKey: 'text') ifTrue: [ (record at: 'text') = (aRequest at: 'text') ifFalse: [ ^ false ] ].
	(aRequest includesKey: 'textContains') ifTrue: [ ((record at: 'text') includesSubstring: (aRequest at: 'textContains')) ifFalse: [ ^ false ] ].
	(aRequest includesKey: 'textRegex') ifTrue: [ ((record at: 'text') matchesRegex: (aRequest at: 'textRegex')) ifFalse: [ ^ false ] ].
	#('visible' 'enabled' 'focused') do: [ :key |
		(aRequest includesKey: key) ifTrue: [ (record at: key) = (aRequest at: key) ifFalse: [ ^ false ] ] ].
	^ true
]

{ #category : 'private - inspection' }
KGUiSceneGraph >> recordFor: anElement parent: parentHandle index: childIndex path: path [
	| id viewModel |
	id := [ anElement id = BlElementId noId
		ifTrue: [ nil ]
		ifFalse: [ anElement id asSymbol asString ] ] on: Error do: [ nil ].
	viewModel := [ (anElement respondsTo: #viewModel)
		ifTrue: [ anElement viewModel ifNil: [ nil ] ifNotNil: [ :model | model class name asString ] ]
		ifFalse: [ nil ] ] on: Error do: [ nil ].
	^ OrderedDictionary new
		at: 'nodeId' put: (self handleFor: anElement);
		at: 'parent' put: parentHandle;
		at: 'childIndex' put: childIndex;
		at: 'path' put: path;
		at: 'class' put: anElement class name asString;
		at: 'elementId' put: id;
		at: 'text' put: (self boundedTextOf: anElement);
		at: 'visibility' put: anElement visibility printString;
		at: 'visible' put: anElement isVisible;
		at: 'effectiveVisible' put: (self effectiveVisibilityOf: anElement);
		at: 'inViewport' put: ([ anElement isVisibleInSpace ] on: Error do: [ false ]);
		at: 'attached' put: anElement isAttachedToSceneGraph;
		at: 'focused' put: anElement isFocused;
		at: 'enabled' put: ([ (anElement respondsTo: #isEnabled) ifTrue: [ anElement isEnabled ] ifFalse: [ true ] ] on: Error do: [ true ]);
		at: 'handlesMouse' put: anElement shouldHandleMouseEvents;
		at: 'opacity' put: anElement opacity;
		at: 'bounds' put: (self boundsDataOf: anElement);
		at: 'childCount' put: anElement children size;
		at: 'viewModelClass' put: viewModel;
		yourself
]

{ #category : 'private - inspection' }
KGUiSceneGraph >> recordsFor: aRequest [
	| space records limit root |
	self pruneHandles.
	space := self selectedSpaceFor: aRequest.
	limit := aRequest at: 'limit' ifAbsent: [ 5000 ].
	root := (aRequest includesKey: 'under')
		ifTrue: [ self elementAt: (aRequest at: 'under') ]
		ifFalse: [ space root ].
	records := OrderedCollection new.
	self visit: root parent: nil index: 1 path: #(1) into: records limit: limit.
	^ { space. records. limit }
]

{ #category : 'public - querying' }
KGUiSceneGraph >> resolveOne: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #BlElement>
	| result |
	result := self query: aRequest.
	(result at: 'count') = 1 ifFalse: [
		self error: ((result at: 'count') = 0
			ifTrue: [ 'UI target did not match any instantiated element' ]
			ifFalse: [ 'UI target is ambiguous; matches: ' , ((result at: 'matches') printStringLimitedTo: 2000) ]) ].
	^ self elementAt: ((result at: 'matches') first at: 'nodeId')
]

{ #category : 'private - spaces' }
KGUiSceneGraph >> selectedSpaceFor: aRequest [
	| all requested |
	all := self spaces.
	requested := aRequest at: 'space' ifAbsent: [ nil ].
	requested ifNotNil: [
		^ all
			detect: [ :space | (self spaceId: space) = requested or: [ space title = requested ] ]
			ifNone: [ self error: 'UI space not found: ' , requested ] ].
	^ (GtWorld defaultWorld notNil and: [ all includes: GtWorld defaultWorld ])
		ifTrue: [ GtWorld defaultWorld ]
		ifFalse: [ all ifEmpty: [ self error: 'no open UI spaces' ] ifNotEmpty: [ all first ] ]
]

{ #category : 'private - spaces' }
KGUiSceneGraph >> spaceId: aSpace [
	^ 'space-' , aSpace identityHash asString
]

{ #category : 'public - spaces' }
KGUiSceneGraph >> spaces [
	<return: #(OrderedCollection<BlSpace>)>
	| result world |
	result := OrderedCollection new.
	BlSpace allOpenSpacesDo: [ :space |
		(space isOpened and: [ (result identityIncludes: space) not ])
			ifTrue: [ result add: space ] ].
	world := GtWorld defaultWorld.
	(world notNil and: [ world isOpened ]) ifTrue: [
		result remove: world ifAbsent: [ ].
		result addFirst: world ].
	^ result
]

{ #category : 'public - inspection' }
KGUiSceneGraph >> spacesData [
	<return: #(Dictionary<String, Any>)>
	^ OrderedDictionary new
		at: 'spaces' put: (self spaces collect: [ :space |
			OrderedDictionary new
				at: 'spaceId' put: (self spaceId: space);
				at: 'class' put: space class name asString;
				at: 'title' put: ([ space title asString ] on: Error do: [ '' ]);
				at: 'opened' put: space isOpened;
				at: 'extent' put: { space extent x. space extent y };
				yourself ]) asArray;
		yourself
]

{ #category : 'public - inspection' }
KGUiSceneGraph >> tree: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| tuple space records limit |
	tuple := self recordsFor: aRequest.
	space := tuple first. records := tuple second. limit := tuple third.
	^ OrderedDictionary new
		at: 'space' put: (self spaceId: space);
		at: 'roots' put: (records ifEmpty: [ #() ] ifNotEmpty: [ { records first at: 'nodeId' } ]);
		at: 'nodes' put: records asArray;
		at: 'nodeCount' put: records size;
		at: 'limit' put: limit;
		at: 'truncated' put: records size >= limit;
		yourself
]

{ #category : 'private - inspection' }
KGUiSceneGraph >> visit: anElement parent: parentHandle index: childIndex path: path into: records limit: limit [
	| record handle |
	records size >= limit ifTrue: [ ^ self ].
	record := self recordFor: anElement parent: parentHandle index: childIndex path: path.
	records add: record.
	handle := record at: 'nodeId'.
	anElement children withIndexDo: [ :child :index |
		self visit: child parent: handle index: index path: path , { index } into: records limit: limit ]
]
