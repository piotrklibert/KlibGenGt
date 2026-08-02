| gitDirectory repositoryUrl |
gitDirectory := (Smalltalk os environment at: 'KLIBGEN_EXPORT_GIT') asFileReference.
repositoryUrl := 'gitlocal://' , gitDirectory fullName , ':master/src'.
Metacello new baseline: 'KlibGenGt'; repository: repositoryUrl; onConflictUseIncoming; get; load: 'CI'.
IceRepository registry detect: [ :repository | repository location fullName = gitDirectory parent fullName ] ifFound: [ :repository | IceRepository registry remove: repository ] ifNone: [ ].
Stdio stdout nextPutAll: 'Loaded project from exact JJ source bridge'; lf; flush.
Smalltalk snapshot: true andQuit: true
