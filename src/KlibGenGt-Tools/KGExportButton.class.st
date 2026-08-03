"
A world-toolbar button that displays and commits live KlibGenGt changes.

- Slots
  - `tool` (`#KGExportTool`, `model`) - Resolves, counts, and commits changes in the managed export repository.
  - `worker` (`#(Process?)`, `lifecycle`) - Runs Iceberg work away from the Bloc UI thread.
- Public API
  - {{gtMethod:KGExportButton class>>#installOn:}}
    Rebuild a world's toolbar so the project export action is present exactly once.
  - {{gtMethod:KGExportButton class>>#uninstallFrom:}}
    Remove project export buttons, subscriptions, and in-flight workers.
  - {{gtMethod:KGExportButton>>#refresh}}
    Refresh the label and enablement from the current repository state.
  - {{gtMethod:KGExportButton>>#tool:}}
    Replace the export model, primarily for isolated widget tests.
"
Class {
	#name : 'KGExportButton',
	#superclass : 'BrButton',
	#instVars : [
		'tool',
		'worker'
	],
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'public - lifecycle' }
KGExportButton class >> installOn: world [
	<arg: #world type: #GtWorld>
	<return: #KGExportButton>
	| worldElement button |
	worldElement := (world root query // GtWorldElement) anyOne.
	worldElement updateToolbarActions.
	button := (world root query // self) anyOne.
	button refresh; requestParentLayout.
	button parent requestParentLayout.
	world root requestLayout.
	world requestNextPulse.
	^ button
]

{ #category : 'public - lifecycle' }
KGExportButton class >> uninstallFrom: world [
	<arg: #world type: #(GtWorld?)>
	<return: #KGExportButton>
	world ifNil: [ ^ self ].
	(world root query // self) all do: #removeFromParent.
	^ self
]

{ #category : 'private - actions' }
KGExportButton >> export [
	<return: #KGExportButton>
	(self isAttachedToSceneGraph not or: [ self space isOpened not ]) ifTrue: [
		tool exportChanges.
		^ self updateCount: tool changeCount ].
	worker ifNotNil: [ ^ self ].
	self disable.
	worker := [
		[ tool exportChanges ]
			on: Error
			do: [ :error | Stdio stderr nextPutAll: error printString; lf; flush ].
		UIManager default defer: [
			worker := nil.
			self refresh ] ] fork.
	^ self
]

{ #category : 'initialization' }
KGExportButton >> initialize [
	<return: #KGExportButton>
	super initialize.
	tool := KGExportTool new.
	self
		id: (BlElementId named: #kgExportButton);
		aptitude: BrGlamorousButtonWithLabelAptitude new;
		hExact: 88;
		vExact: 24;
		label: 'Export (0)';
		action: [ self export ]
]

{ #category : 'private - announcements' }
KGExportButton >> noteProjectChange: anAnnouncement [
	<arg: #anAnnouncement type: #SystemAnnouncement>
	<return: #KGExportButton>
	UIManager default defer: [ self refresh ].
	^ self
]

{ #category : 'hooks' }
KGExportButton >> onAddedToSceneGraph [
	<return: #KGExportButton>
	super onAddedToSceneGraph.
	SystemAnnouncer uniqueInstance unsubscribe: self.
	SystemAnnouncer uniqueInstance weak
		when: MethodAdded send: #noteProjectChange: to: self;
		when: MethodModified send: #noteProjectChange: to: self;
		when: MethodRemoved send: #noteProjectChange: to: self;
		when: MethodRecategorized send: #noteProjectChange: to: self;
		when: MethodRepackaged send: #noteProjectChange: to: self;
		when: ClassAdded send: #noteProjectChange: to: self;
		when: ClassCommented send: #noteProjectChange: to: self;
		when: ClassModifiedClassDefinition send: #noteProjectChange: to: self;
		when: ClassRemoved send: #noteProjectChange: to: self;
		when: ClassRenamed send: #noteProjectChange: to: self;
		when: ClassRepackaged send: #noteProjectChange: to: self;
		when: PackageAdded send: #noteProjectChange: to: self;
		when: PackageRemoved send: #noteProjectChange: to: self;
		when: PackageRenamed send: #noteProjectChange: to: self
]

{ #category : 'hooks' }
KGExportButton >> onRemovedFromSceneGraph [
	<return: #KGExportButton>
	super onRemovedFromSceneGraph.
	SystemAnnouncer uniqueInstance unsubscribe: self.
	worker ifNotNil: [ :process | process terminate ].
	worker := nil.
	^ self
]

{ #category : 'public - accessing' }
KGExportButton >> refresh [
	<return: #KGExportButton>
	^ self updateCount: ([ tool changeCount ] on: Error do: [ 0 ])
]

{ #category : 'public - accessing' }
KGExportButton >> tool: anExportTool [
	<arg: #anExportTool type: #KGExportTool>
	<return: #KGExportButton>
	tool := anExportTool.
	self refresh.
	^ self
]

{ #category : 'private - updating' }
KGExportButton >> updateCount: count [
	<arg: #count type: #Integer>
	<return: #KGExportButton>
	self
		label: 'Export (' , count printString , ')';
		disabled: count = 0.
	^ self
]
