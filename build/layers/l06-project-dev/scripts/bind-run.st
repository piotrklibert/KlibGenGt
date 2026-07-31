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
    subclass: #KGGuiSessionHooks
    instanceVariableNames: ''
    classVariableNames: 'DidOpen'
    package: 'KlibGen-Build-Transient'.
startupClass class compile: 'emitEvent: eventName
    | record output eventPath stream |
    record := Dictionary new
        at: ''schemaVersion'' put: 1;
        at: ''event'' put: eventName;
        at: ''runId'' put: (Smalltalk os environment at: ''KLIBGEN_RUN_ID'' ifAbsent: [ '''' ]);
        at: ''startMode'' put: (Smalltalk os environment at: ''KLIBGEN_GUI_START_MODE'' ifAbsent: [ ''unknown'' ]);
        yourself.
    output := STONJSON toString: record.
    Stdio stdout nextPutAll: ''KLIBGEN_GUI_EVENT ''; nextPutAll: output; lf; flush.
    eventPath := Smalltalk os environment at: ''KLIBGEN_GUI_EVENT_PATH'' ifAbsent: [ ^ self ].
    eventPath asFileReference parent ensureCreateDirectory.
    eventPath asFileReference ensureCreateFile.
    stream := eventPath asFileReference binaryWriteStream.
    [ stream setToEnd; nextPutAll: output utf8Encoded; nextPut: Character lf asciiValue ]
        ensure: [ stream close ]'.
startupClass class compile: 'rebindRepository
    | gitDirectory repository |
    gitDirectory := (Smalltalk os environment at: ''KLIBGEN_EXPORT_GIT'') asFileReference parent.
    repository := IceRepository registry
        detect: [ :each | [ each location basename = ''export'' ] on: Error do: [ false ] ]
        ifNone: [ nil ].
    repository ifNotNil: [ repository location: gitDirectory ]'.
startupClass class compile: 'startUp: isImageStarting
    | mode world staleWorld |
    isImageStarting ifFalse: [ ^ self ].
    DidOpen = true ifTrue: [ ^ self ].
    DidOpen := true.
    self rebindRepository.
    mode := Smalltalk os environment at: ''KLIBGEN_GUI_START_MODE'' ifAbsent: [ ''fresh'' ].
    world := mode = ''fresh''
        ifTrue: [
            staleWorld := GtWorld defaultWorld.
            world := GtWorld openDefault.
            staleWorld ifNotNil: [ staleWorld ~~ world ifTrue: [ staleWorld close ] ].
            world ]
        ifFalse: [ GtWorld defaultWorld ifNil: [ GtWorld openDefault ] ].
    world removeShutdownListener; addShutdownListener.
    mode = ''fresh'' ifTrue: [ world extent: 1600 @ 864 ].
    self emitEvent: (mode = ''resumed'' ifTrue: [ ''resumed'' ] ifFalse: [ ''ready'' ])'.
startupClass class compile: 'shutDown: isImageQuitting
    isImageQuitting ifTrue: [ self emitEvent: ''stopping'' ].
    DidOpen := false'.
SessionManager default
    register: (ClassSessionHandler forClassNamed: startupClass name)
    inCategory: SessionManager default guiCategory
    atPriority: SessionManager default defaultPriority.
Smalltalk snapshot: true andQuit: true
