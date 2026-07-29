| gitDirectory repositoryUrl testPackage suite result failures errors exitCode |

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

testPackage := RPackageOrganizer default packageNamed: 'KlibGenGt-Tests'.
suite := TestSuite named: 'KlibGenGt tests'.
testPackage definedClasses do: [ :eachClass |
    (eachClass inheritsFrom: TestCase)
        ifTrue: [ suite addTest: eachClass suite ] ].

result := suite run.
failures := result failures size.
errors := result errors size.
exitCode := (failures = 0 and: [ errors = 0 ])
    ifTrue: [ 0 ]
    ifFalse: [ 1 ].

Stdio stdout
    nextPutAll: 'Tests run: ';
    nextPutAll: result runCount printString;
    nextPutAll: ', failures: ';
    nextPutAll: failures printString;
    nextPutAll: ', errors: ';
    nextPutAll: errors printString;
    lf;
    flush.

Smalltalk exit: exitCode
