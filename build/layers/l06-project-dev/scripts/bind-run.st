| gitDirectory repositoryUrl startupClass |
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
startupClass := Object
    subclass: #KlibGenGuiStartup
    instanceVariableNames: ''
    classVariableNames: 'DidOpen'
    package: 'KlibGen-Build-Transient'.
startupClass class compile: 'startUp: isImageStarting
    | staleWorld newWorld |
    isImageStarting ifFalse: [ ^ self ].
    DidOpen = true ifTrue: [ ^ self ].
    DidOpen := true.
    staleWorld := GtWorld defaultWorld.
    newWorld := GtWorld openDefault.
    newWorld addShutdownListener.
    newWorld extent: 1600 @ 864.
    staleWorld ifNotNil: [ staleWorld close ]'.
startupClass class compile: 'shutDown: isImageQuitting
    DidOpen := false'.
SessionManager default
    register: (ClassSessionHandler forClassNamed: startupClass name)
    inCategory: SessionManager default guiCategory
    atPriority: SessionManager default defaultPriority.
Smalltalk snapshot: true andQuit: true
