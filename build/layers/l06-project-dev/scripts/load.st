| gitDirectory repositoryUrl |
gitDirectory := (Smalltalk os environment at: 'KLIBGEN_EXPORT_GIT') asFileReference.
repositoryUrl := 'gitlocal://' , gitDirectory fullName , ':master/src'.
Metacello new
    baseline: 'KlibGenGt';
    repository: repositoryUrl;
    onConflictUseIncoming;
    get;
    load: 'CI'.
IceRepository registry
    detect: [ :repository | repository location fullName = gitDirectory parent fullName ]
    ifFound: [ :repository | IceRepository registry remove: repository ]
    ifNone: [ ].
Stdio stdout nextPutAll: 'Loaded L06 from generated JJ export bridge'; lf; flush.
Smalltalk snapshot: true andQuit: true
