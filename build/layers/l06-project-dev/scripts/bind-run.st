| gitDirectory repositoryUrl |
gitDirectory := (Smalltalk os environment at: 'KLIBGEN_EXPORT_GIT') asFileReference.
repositoryUrl := 'gitlocal://' , gitDirectory fullName , ':master/src'.
IceRepository registry
    detect: [ :repository | repository location fullName = gitDirectory parent fullName ]
    ifFound: [ :repository | IceRepository registry remove: repository ]
    ifNone: [ ].
Metacello new
    baseline: 'KlibGenGt';
    repository: repositoryUrl;
    onConflictUseIncoming;
    get;
    load: 'CI'.
Stdio stdout nextPutAll: 'Bound GUI run to '; nextPutAll: repositoryUrl; lf; flush.
BlSpace userScale: 1.25.
GtWorld openDefault.
GtWorld defaultWorld
    ifNil: [ self error: 'Failed to open the Glamorous Toolkit world' ]
