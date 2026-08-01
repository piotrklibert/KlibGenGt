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
KGGuiSessionHooks install.
SessionManager default
    register: (ClassSessionHandler forClassNamed: KGGuiSessionHooks name)
    inCategory: SessionManager default guiCategory
    atPriority: SessionManager default defaultPriority.
Smalltalk snapshot: true andQuit: true
