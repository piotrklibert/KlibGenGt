| gitDirectory repositoryUrl repository outputDirectory writer |
gitDirectory := (Smalltalk os environment at: 'KLIBGEN_EXPORT_GIT') asFileReference.
repositoryUrl := 'gitlocal://' , gitDirectory fullName , ':master/src'.
Metacello new baseline: 'KlibGenGt'; repository: repositoryUrl; onConflictUseIncoming; get; load: 'CI'.
repository := IceRepository registry
	detect: [ :each | each location fullName = gitDirectory parent fullName ]
	ifNone: [ self error: 'Loaded project source repository is not registered in Iceberg' ].
outputDirectory := (Smalltalk os environment at: 'KLIBGEN_TONEL_OUTPUT') asFileReference.
outputDirectory ensureCreateDirectory.
writer := TonelWriter on: outputDirectory.
repository workingCopy packages
	select: [ :package |
		package name = 'BaselineOfKlibGenGt'
			or: [ package name beginsWith: 'KlibGenGt-' ] ]
	thenDo: [ :package |
		writer writeSnapshot: (repository workingCopy snapshotForPackage: package) ].
IceRepository registry remove: repository.
Stdio stdout nextPutAll: 'Loaded project from exact JJ source bridge'; lf; flush.
Smalltalk snapshot: true andQuit: true
