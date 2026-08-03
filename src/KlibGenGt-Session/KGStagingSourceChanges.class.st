"
A shared source capability backed by the named staging repository attached to the session.

- Slots
  - `manifest` (`#KGSessionV1`, `provenance`) - Launch manifest retained independently of the mutable global session installation.
- Public API
  - {{gtMethod:KGStagingSourceChanges>>#available}}
    Answer true for controls and callers.
  - {{gtMethod:KGStagingSourceChanges>>#changeCount}}
    Count modified KlibGenGt packages in the attached repository.
  - {{gtMethod:KGStagingSourceChanges>>#exportChanges}}
    Commit pending project changes and notify the host staging service.
  - {{gtMethod:KGStagingSourceChanges>>#promoteChanges}}
    Request conflict-checked host promotion and answer its structured response.
  - {{gtMethod:KGStagingSourceChanges>>#sourceRepository}}
    Answer the attached Iceberg repository for staged source tooling.
  - {{gtMethod:KGStagingSourceChanges>>#sourceRoot}}
    Answer the attached repository's Tonel source directory.
  - {{gtMethod:KGStagingSourceChanges>>#headCommit}}
    Answer the commit loaded by the current staging session.
"
Class {
	#name : 'KGStagingSourceChanges',
	#superclass : 'Object',
	#instVars : [
		'manifest'
	],
	#category : 'KlibGenGt-Session',
	#package : 'KlibGenGt-Session'
}

{ #category : 'testing' }
KGStagingSourceChanges >> available [
	<return: #Boolean>
	^ true
]

{ #category : 'accessing' }
KGStagingSourceChanges >> changeCount [
	<return: #Integer>
	^ self repository modifiedPackages count: [ :package |
		package name asString beginsWith: 'KlibGenGt' ]
]

{ #category : 'private - configuration' }
KGStagingSourceChanges >> ensureGitIdentityFor: repository [
	<arg: #repository type: #IceRepository>
	<return: #KGStagingSourceChanges>
	self runGitConfiguration: #('user.name' 'KlibGenGt Export') for: repository.
	self runGitConfiguration: #('user.email' 'export@localhost') for: repository.
	^ self
]

{ #category : 'actions' }
KGStagingSourceChanges >> exportChanges [
	<return: #(IceCommit?)>
	| count repository gitRepository commit |
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
	[ self requestSourceOperation: 'source.export' ] on: Error do: [ :error |
		"The durable Git commit is authoritative. A later host status or attachment
		 reconciles it if this best-effort notification cannot be delivered."
		Stdio stderr nextPutAll: error printString; lf; flush ].
	^ commit
]

{ #category : 'accessing' }
KGStagingSourceChanges >> headCommit [
	<return: #String>
	^ manifest inputs at: 'stagingHeadCommit'
]

{ #category : 'private - initialization' }
KGStagingSourceChanges >> initializeManifest: aManifest [
	<arg: #aManifest type: #KGSessionV1>
	<return: #KGStagingSourceChanges>
	manifest := aManifest.
	^ self
]

{ #category : 'actions' }
KGStagingSourceChanges >> promoteChanges [
	<return: #(Dictionary<String, Any>)>
	^ self requestSourceOperation: 'source.promote'
]

{ #category : 'private - accessing' }
KGStagingSourceChanges >> repository [
	<return: #IceRepository>
	| gitPath location repository |
	gitPath := (manifest inputs at: 'sourceGit') asFileReference.
	location := gitPath parent fullName.
	repository := IceRepository registry
		detect: [ :each | [ each location fullName = location ] on: Error do: [ false ] ]
		ifNone: [ self error: 'The session source repository is not registered in Iceberg' ].
	(repository head isDetached or: [ repository workingCopy isDetached ])
		ifTrue: [ repository checkoutBranch: 'master' ].
	^ repository
]

{ #category : 'private - requests' }
KGStagingSourceChanges >> requestEnvelopeFor: operation requestId: requestId [
	<arg: #operation type: #String>
	<arg: #requestId type: #String>
	<return: #(Dictionary<String, Any>)>
	^ OrderedDictionary new
		at: 'schemaVersion' put: 1;
		at: 'requestId' put: requestId;
		at: 'sessionId' put: manifest sessionId;
		at: 'stagingArea' put: (manifest inputs at: 'stagingArea');
		at: 'operation' put: operation;
		yourself
]

{ #category : 'private - requests' }
KGStagingSourceChanges >> requestSourceOperation: operation [
	<arg: #operation type: #String>
	<return: #(Dictionary<String, Any>)>
	| paths requestId requestPath responsePath deadline response |
	paths := manifest paths.
	paths sourceRequests ifNil: [ self error: 'The session has no source request spool' ].
	paths sourceResponses ifNil: [ self error: 'The session has no source response spool' ].
	requestId := UUID new asString.
	requestPath := paths sourceRequests asFileReference / (requestId , '.json').
	responsePath := paths sourceResponses asFileReference / (requestId , '.json').
	KGAtomicJsonWriter
		write: (self requestEnvelopeFor: operation requestId: requestId)
		to: requestPath.
	deadline := DateAndTime now + 30 seconds.
	[ responsePath isFile or: [ DateAndTime now >= deadline ] ] whileFalse: [
		(Delay forMilliseconds: 20) wait ].
	responsePath isFile ifFalse: [ self error: 'Timed out waiting for the host source service' ].
	response := STONJSON fromString: responsePath contents.
	responsePath ensureDelete.
	^ response
]

{ #category : 'private - configuration' }
KGStagingSourceChanges >> runGitConfiguration: arguments for: repository [
	<arg: #arguments type: #(Array<String>)>
	<arg: #repository type: #IceRepository>
	<return: #KGStagingSourceChanges>
	| process |
	process := GtSubprocessWithInMemoryOutput new
		command: 'git';
		arguments: { '-C'. repository location fullName. 'config' } , arguments;
		runAndWait.
	process isSuccess ifFalse: [
		self error: 'Unable to configure the session source repository: ', process stderr trimBoth ].
	^ self
]

{ #category : 'accessing' }
KGStagingSourceChanges >> sourceRepository [
	<return: #IceRepository>
	^ self repository
]

{ #category : 'accessing' }
KGStagingSourceChanges >> sourceRoot [
	<return: #FileReference>
	^ self repository location / 'src'
]
