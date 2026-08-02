"Session hooks for one writable GUI run and its private Iceberg repository.

- Slots
  - `DidOpen` (`#Boolean`, class state, `system startup`) - Records whether startup already opened or reused the run world.
  - `HasRestorableState` (`#Boolean`, class state, `shutdown`) - Stays true after this run adds a tool tab, even if that tab is later closed.
- Public API
  - {{gtMethod:KGGuiSessionHooks class>>#install}}
    Install the Iceberg commit subscription idempotently; world UI is installed when a session is bound.
  - {{gtMethod:KGGuiSessionHooks class>>#uninstall}}
    Remove every Iceberg subscription owned by this hook.
  - {{gtMethod:KGGuiSessionHooks class>>#emitEvent:}}
    Append one named GUI lifecycle event to the host JSONL journal.
  - {{gtMethod:KGGuiSessionHooks class>>#handlesRepositoryPath:}}
    Answer whether a normalized path is the exact private export for this run.
  - {{gtMethod:KGGuiSessionHooks class>>#ensureQuitPolicyOn:}}
    Install exactly one confirmation handler and one post-close image shutdown listener.
  - {{gtMethod:KGGuiSessionHooks class>>#requestQuitFrom:}}
    Route a tools-menu Quit button through the same confirmation prompt as a window close.
  - {{gtMethod:KGGuiSessionHooks class>>#requestQuitIn:}}
    Show the save, discard, or cancel confirmation prompt in a GUI world.
  - {{gtMethod:KGGuiSessionHooks class>>#shouldConfirmQuitIn:}}
    Answer whether a world contains restorable tool state that should be saved or discarded explicitly.
  - {{gtMethod:KGGuiSessionHooks class>>#noteRestorableState}}
    Mark the current GUI run as containing state worth saving or explicitly discarding.
  - {{gtMethod:KGGuiSessionHooks class>>#startUp:}}
    Rebind the private repository, install the hook, and open or restore the run world.
  - {{gtMethod:KGGuiSessionHooks class>>#shutDown:}}
    Stop live UI control, emit shutdown state, and unsubscribe when the image quits.
"
Class {
	#name : 'KGGuiSessionHooks',
	#superclass : 'Object',
	#classVars : [
		'DidOpen',
		'HasRestorableState'
	],
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'private - events' }
KGGuiSessionHooks class >> appendEventRecord: record [
	<arg: #record type: #(Dictionary<String, Any>)>
	<return: #KGGuiSessionHooks>
	| output eventPath stream |
	output := STONJSON toString: record.
	Stdio stdout nextPutAll: 'KLIBGEN_GUI_EVENT '; nextPutAll: output; lf; flush.
	eventPath := (KGSession current manifest at: 'paths') at: 'eventJournal' ifAbsent: [ ^ self ].
	eventPath asFileReference parent ensureCreateDirectory.
	eventPath asFileReference ensureCreateFile.
	stream := eventPath asFileReference binaryWriteStream.
	[ stream setToEnd; nextPutAll: output utf8Encoded; nextPut: Character lf asciiValue ]
		ensure: [ stream close ]
]

{ #category : 'public - events' }
KGGuiSessionHooks class >> emitEvent: eventName [
	<arg: #eventName type: #String>
	<return: #KGGuiSessionHooks>
	^ self appendEventRecord: (Dictionary new
		at: 'schemaVersion' put: 1;
		at: 'event' put: eventName;
		at: 'sessionId' put: KGSession current id;
		at: 'startMode' put: ((KGSession current manifest at: 'preset') at: 'startMode' ifAbsent: [ 'unknown' ]);
		yourself)
]

{ #category : 'private - events' }
KGGuiSessionHooks class >> emitIcebergCommittedForRepositoryPath: repositoryPath [
	<arg: #repositoryPath type: #String>
	<return: #KGGuiSessionHooks>
	^ self appendEventRecord: (Dictionary new
		at: 'schemaVersion' put: 1;
		at: 'event' put: 'iceberg-committed';
		at: 'sessionId' put: KGSession current id;
		at: 'startMode' put: ((KGSession current manifest at: 'preset') at: 'startMode' ifAbsent: [ 'unknown' ]);
		at: 'repositoryPath' put: repositoryPath asFileReference fullName;
		yourself)
]

{ #category : 'public - shutdown' }
KGGuiSessionHooks class >> ensureQuitPolicyOn: world [
	<arg: #world type: #GtWorld>
	<return: #KGGuiSessionHooks>
	world removeEventHandlersSuchThat: [ :eachHandler |
		(eachHandler isKindOf: GtWorldCloseEventHandler)
			or: [ eachHandler isKindOf: KGGuiWorldCloseEventHandler ] ].
	world addEventHandler: KGGuiWorldCloseEventHandler new.
	world tabGroup viewModel removeEventHandlersSuchThat: [ :eachHandler |
		eachHandler isKindOf: KGGuiTabAddedEventHandler ].
	world tabGroup viewModel addEventHandler: KGGuiTabAddedEventHandler new.
	world removeShutdownListener; addShutdownListener.
	^ self
]

{ #category : 'private - startup' }
KGGuiSessionHooks class >> scheduleExportButtonInstallationOn: world replacing: staleWorld [
	<arg: #world type: #GtWorld>
	<arg: #staleWorld type: #(GtWorld?)>
	<return: #KGGuiSessionHooks>
	world root enqueueTask: (BlTaskAction new action: [
		world markAsDefault.
		staleWorld ifNotNil: [
			staleWorld ~~ world ifTrue: [
				staleWorld removeEventHandlersSuchThat: [ :eachHandler |
					(eachHandler isKindOf: GtWorldCloseEventHandler)
						or: [ eachHandler isKindOf: KGGuiWorldCloseEventHandler ] ].
				"This task runs on the shared Bloc universe pulse. Close synchronously so
				 the stale release world cannot remain registered without another pulse."
				staleWorld universe closeSpaceSynchronously: staleWorld ] ].
		world markAsDefault.
		KGExportButton installOn: world ]).
	world requestNextPulse.
	^ self
]

{ #category : 'public - testing' }
KGGuiSessionHooks class >> handlesRepositoryPath: repositoryPath [
	<arg: #repositoryPath type: #String>
	<return: #Boolean>
	| gitPath |
	gitPath := ((KGSession current manifest at: 'inputs') at: 'sourceGit' ifAbsent: [ ^ false ]).
	^ repositoryPath asFileReference fullName
		= gitPath asFileReference parent fullName
]

{ #category : 'private - events' }
KGGuiSessionHooks class >> handleIcebergCommit: announcement [
	<arg: #announcement type: #IceCommited>
	<return: #KGGuiSessionHooks>
	| repositoryPath |
	repositoryPath := announcement repository location fullName.
	(self handlesRepositoryPath: repositoryPath) ifTrue: [
		self emitIcebergCommittedForRepositoryPath: repositoryPath ].
	^ self
]

{ #category : 'public - subscriptions' }
KGGuiSessionHooks class >> install [
	<return: #KGGuiSessionHooks>
	self uninstall.
	Iceberg announcer weak
		when: IceCommited
		send: #handleIcebergCommit:
		to: self.
	^ self
]

{ #category : 'public - shutdown' }
KGGuiSessionHooks class >> noteRestorableState [
	<return: #KGGuiSessionHooks>
	HasRestorableState := true.
	^ self
]

{ #category : 'private - startup' }
KGGuiSessionHooks class >> rebindRepository [
	<return: #KGGuiSessionHooks>
	| gitDirectory repository |
	gitDirectory := (((KGSession current manifest at: 'inputs') at: 'sourceGit') asFileReference) parent.
	repository := IceRepository registry
		detect: [ :each | [ each location basename = 'export' ] on: Error do: [ false ] ]
		ifNone: [ nil ].
	repository ifNotNil: [ repository location: gitDirectory ].
	^ self
]

{ #category : 'public - shutdown' }
KGGuiSessionHooks class >> requestQuitFrom: button [
	<arg: #button type: #BrButton>
	<return: #KGGuiSessionHooks>
	| world |
	world := button space.
	button fireEvent: BrDropdownHideWish new.
	world requestClose.
	^ self
]

{ #category : 'public - shutdown' }
KGGuiSessionHooks class >> requestQuitIn: world [
	<arg: #world type: #GtWorld>
	<return: #KGGuiSessionHooks>
	| prompt question save discard cancel worldElement |
	worldElement := world root.
	worldElement childWithId: GtWorldShutdownPromptId ifFound: [ ^ self ] ifNone: [ ].
	prompt := BrHorizontalPane new hMatchParent; cellSpacing: 10; vFitContent; background: worldElement theme status errorBackgroundColor lighter lighter; alignCenterLeft; padding: (BlInsets top: 10 bottom: 10); id: GtWorldShutdownPromptId.
	question := BrLabel new aptitude: BrGlamorousLabelAptitude; text: 'Save workspace before quitting?'.
	save := BrButton new aptitude: BrGlamorousButtonWithLabelAptitude; beSmallSize; label: 'Save and quit'; action: [ :button | button disable. prompt removeFromParent. KGSession current persistence saveAndQuit ].
	discard := BrButton new aptitude: BrGlamorousButtonWithLabelAptitude; beSmallSize; label: 'Just quit'; action: [ :button | button disable. prompt removeFromParent. KGSession current persistence discardAndQuit ].
	cancel := BrButton new aptitude: BrGlamorousButtonWithLabelAptitude; beSmallSize; label: 'Don''t quit'; action: [ :button | prompt removeFromParent ].
	prompt addChildren: { question. save. discard. cancel }.
	worldElement addChild: prompt.
	^ self
]

{ #category : 'public - shutdown' }
KGGuiSessionHooks class >> shouldConfirmQuitIn: world [
	<arg: #world type: #GtWorld>
	<return: #Boolean>
	^ HasRestorableState = true or: [ world tabGroup tabs size > 1 ]
]

{ #category : 'system startup' }
KGGuiSessionHooks class >> shutDown: isImageQuitting [
	<arg: #isImageQuitting type: #Boolean>
	<return: #KGGuiSessionHooks>
	isImageQuitting ifTrue: [
		KGUiControlService uninstall.
		self emitEvent: 'stopping'.
		self uninstall ].
	DidOpen := false.
	HasRestorableState := false.
	^ self
]

{ #category : 'system startup' }
KGGuiSessionHooks class >> startUp: isImageStarting [
	<arg: #isImageStarting type: #Boolean>
	<return: #KGGuiSessionHooks>
	| mode world staleWorld |
	isImageStarting ifFalse: [ ^ self ].
	(Smalltalk os environment at: 'KLIBGEN_SESSION_MANIFEST' ifAbsent: [ nil ]) ifNotNil: [ :manifestPath |
		KGSessionBootstrap installManifest: (STONJSON fromString: manifestPath asFileReference contents) ].
	DidOpen = true ifTrue: [ ^ self ].
	DidOpen := true.
	HasRestorableState := false.
	self rebindRepository; install.
	mode := (KGSession current manifest at: 'preset') at: 'startMode' ifAbsent: [ 'fresh' ].
	world := mode = 'fresh'
		ifTrue: [
			staleWorld := GtWorld defaultWorld.
			GtWorld openDefault ]
		ifFalse: [ GtWorld defaultWorld ifNil: [ GtWorld openDefault ] ].
	self ensureQuitPolicyOn: world.
	self scheduleExportButtonInstallationOn: world replacing: staleWorld.
	mode = 'fresh' ifTrue: [ world extent: 1600 @ 864 ].
	KGUiControlService install.
	self emitEvent: (mode = 'resumed' ifTrue: [ 'resumed' ] ifFalse: [ 'ready' ]).
	^ self
]

{ #category : 'public - subscriptions' }
KGGuiSessionHooks class >> uninstall [
	<return: #KGGuiSessionHooks>
	KGExportButton uninstallFrom: GtWorld defaultWorld.
	KGUiControlService uninstall.
	Iceberg announcer unsubscribe: self.
	^ self
]
