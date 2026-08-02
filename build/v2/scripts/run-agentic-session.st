| gitDirectory repositoryUrl |
gitDirectory := (Smalltalk os environment at: 'KLIBGEN_STAGING_GIT') asFileReference.
repositoryUrl := 'gitlocal://' , gitDirectory fullName , ':master/src'.
Metacello new
    baseline: 'KlibGenGt';
    repository: repositoryUrl;
    onConflictUseIncoming;
    get;
    load: 'CI'.
KGSessionBootstrap runFromEnvironment
