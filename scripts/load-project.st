| sourceDirectory |

sourceDirectory := FileSystem workingDirectory / 'src'.

Metacello new
    baseline: 'KlibGenGt';
    repository: 'tonel://' , sourceDirectory fullName;
    load: 'CI'.

Stdio stdout
    nextPutAll: 'KlibGenGt loaded from ';
    nextPutAll: sourceDirectory fullName;
    lf;
    flush.

Smalltalk exit: 0
