| gitDirectory repositoryUrl projectClass |

gitDirectory := FileSystem workingDirectory / 'export' / '.git'.
repositoryUrl := 'gitlocal://' , gitDirectory fullName , ':master/src'.

Metacello new
    baseline: 'KlibGenGt';
    repository: repositoryUrl;
    load: 'CI'.

projectClass := Smalltalk
    at: #KlibGenGt
    ifAbsent: [
        Stdio stderr
            nextPutAll: 'KlibGenGt class was not found after loading the project.';
            lf;
            flush.
        Smalltalk exit: 1 ].

(projectClass projectName = 'KlibGenGt')
    ifFalse: [
        Stdio stderr
            nextPutAll: 'KlibGenGt projectName sanity check failed.';
            lf;
            flush.
        Smalltalk exit: 1 ].

Stdio stdout
    nextPutAll: 'Smoke check passed: KlibGenGt loaded from export Git repository.';
    lf;
    flush.

Smalltalk exit: 0
