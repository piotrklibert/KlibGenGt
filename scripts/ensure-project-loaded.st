| gitDirectory repositoryUrl |

gitDirectory := FileSystem workingDirectory / 'export' / '.git'.
repositoryUrl := 'gitlocal://' , gitDirectory fullName , ':master/src'.

Metacello new
    baseline: 'KlibGenGt';
    repository: repositoryUrl;
    load: 'CI'.

Stdio stdout
    nextPutAll: 'KlibGenGt loaded into GUI image from ';
    nextPutAll: repositoryUrl;
    lf;
    flush.

BlSpace userScale: 1.25.
