"
A world-toolbar button that requests conflict-checked promotion of the attached staging area.

- Slots
  - `tool` (`#KGExportTool`, `model`) - Delegates promotion to the installed source capability.
  - `worker` (`#(Process?)`, `lifecycle`) - Runs the host request away from the Bloc UI thread.
  - `lastResult` (`#(Dictionary<String, Any>?)`, `status`) - Last structured host response shown by the button.
- Public API
  - {{gtMethod:KGPromoteButton>>#lastResult}}
    Answer the last structured promotion response.
  - {{gtMethod:KGPromoteButton>>#tool:}}
    Replace the promotion model, primarily for isolated widget tests.
"
Class {
	#name : 'KGPromoteButton',
	#superclass : 'BrButton',
	#instVars : [
		'tool',
		'worker',
		'lastResult'
	],
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'initialization' }
KGPromoteButton >> initialize [
	<return: #KGPromoteButton>
	super initialize.
	tool := KGExportTool new.
	self
		id: (BlElementId named: #kgPromoteButton);
		aptitude: BrGlamorousButtonWithLabelAptitude new;
		hExact: 88;
		vExact: 24;
		label: 'Promote';
		action: [ self promote ]
]

{ #category : 'public - accessing' }
KGPromoteButton >> lastResult [
	<return: #Any>
	^ lastResult
]

{ #category : 'hooks' }
KGPromoteButton >> onRemovedFromSceneGraph [
	<return: #KGPromoteButton>
	super onRemovedFromSceneGraph.
	worker ifNotNil: [ :process | process terminate ].
	worker := nil.
	^ self
]

{ #category : 'private - actions' }
KGPromoteButton >> promote [
	<return: #KGPromoteButton>
	worker ifNotNil: [ ^ self ].
	self disable; label: 'Promoting'.
	worker := [
		[ lastResult := tool promoteChanges ]
			on: Error
			do: [ :error |
				lastResult := Dictionary new
					at: 'ok' put: false;
					at: 'error' put: error printString;
					yourself ].
		UIManager default defer: [
			worker := nil.
			self enable; label: ((lastResult at: 'ok' ifAbsent: [ false ])
				ifTrue: [ 'Promoted' ]
				ifFalse: [ 'Conflict' ]) ] ] fork.
	^ self
]

{ #category : 'public - accessing' }
KGPromoteButton >> tool: anExportTool [
	<arg: #anExportTool type: #KGExportTool>
	<return: #KGPromoteButton>
	tool := anExportTool.
	^ self
]
