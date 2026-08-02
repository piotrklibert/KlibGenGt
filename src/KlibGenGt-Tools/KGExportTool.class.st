"Commit the live image's project changes to the managed GUI export repository.

- Public API
  - {{gtMethod:KGExportTool>>#changeCount}}
    Answer the number of modified KlibGenGt packages in Iceberg.
  - {{gtMethod:KGExportTool>>#commitTitle}}
    Answer the synthetic title for the current export commit.
  - {{gtMethod:KGExportTool>>#exportChanges}}
    Commit every pending repository change and announce the Iceberg commit.
"
Class {
	#name : 'KGExportTool',
	#superclass : 'Object',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'public - accessing' }
KGExportTool >> changeCount [
	<return: #Integer>
	^ self repository modifiedPackages count: [ :package |
		package name asString beginsWith: 'KlibGenGt' ]
]

{ #category : 'public - accessing' }
KGExportTool >> commitTitle [
	<return: #String>
	^ 'Export KlibGenGt changes (' , self changeCount printString , ')'
]

{ #category : 'public - actions' }
KGExportTool >> exportChanges [
	<return: #(IceCommit?)>
	| count gitRepository repository commit |
	count := self changeCount.
	count = 0 ifTrue: [ ^ nil ].
	repository := self repository.
	self ensureGitIdentityFor: repository.
	gitRepository := GtGitRepository fromIcebergRepository: repository.
	commit := repository workingCopy
		commitChanges: gitRepository workingCopyDiff
		withMessage: ('Export KlibGenGt changes (' , count printString , ')').
	Iceberg announcer
		announce: (IceRepositoryModified for: repository);
		announce: (IceCommited for: repository).
	^ commit
]

{ #category : 'private - configuration' }
KGExportTool >> ensureGitIdentityFor: repository [
	<arg: #repository type: #IceRepository>
	<return: #KGExportTool>
	self
		runGitConfiguration: { 'user.name'. 'KlibGenGt Export' }
		for: repository.
	self
		runGitConfiguration: { 'user.email'. 'export@localhost' }
		for: repository.
	^ self
]

{ #category : 'private - accessing' }
KGExportTool >> repository [
	<return: #IceRepository>
	| location |
	location := (Smalltalk os environment
		at: 'KLIBGEN_EXPORT_GIT'
		ifAbsent: [ self error: 'This image is not attached to a managed GUI export repository' ])
		asFileReference parent fullName.
	^ IceRepository registry
		detect: [ :each |
			[ each location fullName = location ]
				on: Error
				do: [ false ] ]
		ifNone: [ self error: 'The managed GUI export repository is not registered in Iceberg' ]
]

{ #category : 'private - configuration' }
KGExportTool >> runGitConfiguration: arguments for: repository [
	<arg: #arguments type: #(Array<String>)>
	<arg: #repository type: #IceRepository>
	<return: #KGExportTool>
	| process |
	process := GtSubprocessWithInMemoryOutput new
		command: 'git';
		arguments: { '-C'. repository location fullName. 'config' } , arguments;
		runAndWait.
	process isSuccess ifFalse: [
		self error: 'Unable to configure the managed GUI export repository: '
			, process stderr trimBoth ].
	^ self
]
