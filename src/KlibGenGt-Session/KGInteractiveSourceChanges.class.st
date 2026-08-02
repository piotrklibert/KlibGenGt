"
Export live project changes through the session's explicitly declared source repository.

- Slots
  - none
- Public API
  - {{gtMethod:KGInteractiveSourceChanges>>#available}}
    Answer true for controls and callers.
  - {{gtMethod:KGInteractiveSourceChanges>>#changeCount}}
    Count modified KlibGenGt packages.
  - {{gtMethod:KGInteractiveSourceChanges>>#exportChanges}}
    Commit pending project changes to the session repository.
"
Class { #name : 'KGInteractiveSourceChanges', #superclass : 'Object', #category : 'KlibGenGt-Session', #package : 'KlibGenGt-Session' }

{ #category : 'testing' }
KGInteractiveSourceChanges >> available [ <return: #Boolean> ^ true ]

{ #category : 'accessing' }
KGInteractiveSourceChanges >> changeCount [
	<return: #Integer>
	^ self repository modifiedPackages count: [ :package | package name asString beginsWith: 'KlibGenGt' ]
]

{ #category : 'actions' }
KGInteractiveSourceChanges >> exportChanges [
	<return: #(IceCommit?)>
	| count repository gitRepository commit |
	count := self changeCount. count = 0 ifTrue: [ ^ nil ].
	repository := self repository. self ensureGitIdentityFor: repository.
	gitRepository := GtGitRepository fromIcebergRepository: repository.
	commit := repository workingCopy commitChanges: gitRepository workingCopyDiff withMessage: ('Export KlibGenGt changes (' , count printString , ')').
	Iceberg announcer announce: (IceRepositoryModified for: repository); announce: (IceCommited for: repository).
	^ commit
]

{ #category : 'private - configuration' }
KGInteractiveSourceChanges >> ensureGitIdentityFor: repository [
	<arg: #repository type: #IceRepository> <return: #KGInteractiveSourceChanges>
	self runGitConfiguration: #('user.name' 'KlibGenGt Export') for: repository.
	self runGitConfiguration: #('user.email' 'export@localhost') for: repository. ^ self
]

{ #category : 'private - accessing' }
KGInteractiveSourceChanges >> repository [
	<return: #IceRepository>
	| gitPath location |
	gitPath := (KGSession current manifest inputs at: 'sourceGit') asFileReference.
	location := gitPath parent fullName.
	^ IceRepository registry detect: [ :each | [ each location fullName = location ] on: Error do: [ false ] ] ifNone: [ self error: 'The session source repository is not registered in Iceberg' ]
]

{ #category : 'private - configuration' }
KGInteractiveSourceChanges >> runGitConfiguration: arguments for: repository [
	<arg: #arguments type: #(Array<String>)> <arg: #repository type: #IceRepository> <return: #KGInteractiveSourceChanges>
	| process |
	process := GtSubprocessWithInMemoryOutput new command: 'git'; arguments: { '-C'. repository location fullName. 'config' } , arguments; runAndWait.
	process isSuccess ifFalse: [ self error: 'Unable to configure the session source repository: ', process stderr trimBoth ]. ^ self
]
