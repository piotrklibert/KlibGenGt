| manifestPath manifest gitDirectory repositoryUrl |
manifestPath := (Smalltalk os environment at: 'KLIBGEN_SESSION_MANIFEST') asFileReference.
manifest := STONJSON fromString: manifestPath contents.
KGSessionBootstrap installManifest: manifest.
gitDirectory := ((manifest at: 'inputs') at: 'sourceGit') asFileReference.
repositoryUrl := 'gitlocal://' , gitDirectory fullName , ':master/src'.
IceRepository registry
	detect: [ :repository | [ repository location fullName = gitDirectory parent fullName ] on: Error do: [ false ] ]
	ifFound: [ :repository | IceRepository registry remove: repository ]
	ifNone: [ ].
Metacello new baseline: 'KlibGenGt'; repository: repositoryUrl; onConflictUseIncoming; get; load: 'CI'.
BlSpace userScale: 1.25.
KGGuiSessionHooks install.
SessionManager default
	register: (ClassSessionHandler forClassNamed: KGGuiSessionHooks name)
	inCategory: SessionManager default guiCategory
	atPriority: SessionManager default defaultPriority.
Stdio stdout nextPutAll: 'Bound v0.2 GUI workspace'; lf; flush.
Smalltalk snapshot: true andQuit: true
