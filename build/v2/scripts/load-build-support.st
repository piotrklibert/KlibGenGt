| gitDirectory repositoryUrl |
gitDirectory := (Smalltalk os environment at: 'KLIBGEN_BUILD_SOURCE_GIT') asFileReference.
repositoryUrl := 'gitlocal://' , gitDirectory fullName , ':master/src'.
Metacello new
	baseline: 'KlibGenGt';
	repository: repositoryUrl;
	onConflictUseIncoming;
	get;
	load: 'BuildSupport'.
IceRepository registry
	detect: [ :repository | repository location fullName = gitDirectory parent fullName ]
	ifFound: [ :repository | IceRepository registry remove: repository ]
	ifNone: [ ].
Stdio stdout nextPutAll: 'Loaded KlibGenGt build support'; lf; flush.
Smalltalk snapshot: true andQuit: true
