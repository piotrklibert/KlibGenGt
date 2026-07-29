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
    nextPutAll: 'KlibGenGt loaded into GUI image from ';
    nextPutAll: repositoryUrl;
    lf;
    flush.

BlSpace userScale: 1.25.
