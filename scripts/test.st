| sourceDirectory testPackage suite result failures errors exitCode |

sourceDirectory := FileSystem workingDirectory / 'src'.

Metacello new
    baseline: 'KlibGenGt';
    repository: 'tonel://' , sourceDirectory fullName;
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
