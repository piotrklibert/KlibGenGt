| gitDirectory repositoryUrl |

gitDirectory := FileSystem workingDirectory / 'export' / '.git'.
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

Stdio stdout
    nextPutAll: 'KlibGenGt loaded from ';
    nextPutAll: repositoryUrl;
    lf;
    flush.

Smalltalk exit: 0
