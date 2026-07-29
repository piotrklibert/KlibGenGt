| gitDirectory repositoryUrl checkerClass results invalid |

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

checkerClass := Smalltalk
    at: #KGCheckTypePragmas
    ifAbsent: [
        Stdio stderr
            nextPutAll: 'KGCheckTypePragmas was not found after loading the project.';
            lf;
            flush.
        Smalltalk exit: 1 ].

results := checkerClass new inProject.
invalid := results reject: [ :each | each at: #valid ].

results ifEmpty: [
    Stdio stderr
        nextPutAll: 'No documentation type annotations were found.';
        lf;
        flush.
    Smalltalk exit: 1 ].

invalid ifNotEmpty: [
    Stdio stderr
        nextPutAll: 'Invalid documentation type annotations:';
        lf.
    invalid do: [ :each |
        Stdio stderr
            nextPutAll: (each at: #class) asString;
            nextPutAll: ' | ';
            nextPutAll: (each at: #source);
            nextPutAll: ' | ';
            nextPutAll: (each at: #type);
            nextPutAll: ' | ';
            nextPutAll: (each at: #message);
            lf ].
    Stdio stderr flush.
    Smalltalk exit: 1 ].

Stdio stdout
    nextPutAll: 'Checked ';
    nextPutAll: results size printString;
    nextPutAll: ' documentation type annotations.';
    lf;
    flush.

Smalltalk exit: 0
