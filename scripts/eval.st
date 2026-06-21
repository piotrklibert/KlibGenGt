| gitDirectory repositoryUrl expression result |

gitDirectory := FileSystem workingDirectory / 'export' / '.git'.
repositoryUrl := 'gitlocal://' , gitDirectory fullName , ':master/src'.

Metacello new
    baseline: 'KlibGenGt';
    repository: repositoryUrl;
    load: 'CI'.

expression := Smalltalk os environment
    at: 'GT_EVAL'
    ifAbsent: [
        Stdio stderr
            nextPutAll: 'GT_EVAL is missing. Use: just eval "Smalltalk expression"';
            lf;
            flush.
        Smalltalk exit: 2 ].

result := Smalltalk compiler evaluate: expression.

Stdio stdout
    nextPutAll: result printString;
    lf;
    flush.

Smalltalk exit: 0
