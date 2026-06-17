| sourceDirectory projectClass |

sourceDirectory := FileSystem workingDirectory / 'src'.

Metacello new
    baseline: 'KlibGenGt';
    repository: 'tonel://' , sourceDirectory fullName;
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
    nextPutAll: 'Smoke check passed: KlibGenGt loaded from local src.';
    lf;
    flush.

Smalltalk exit: 0
