| package suite result failures errors |
(Smalltalk includesKey: #KlibGenGt) ifFalse: [ Smalltalk exit: 1 ].
KlibGenGt projectName = 'KlibGenGt' ifFalse: [ Smalltalk exit: 1 ].
package := RPackageOrganizer default packageNamed: 'KlibGenGt-Tests'.
suite := TestSuite named: 'KlibGenGt tests'.
package definedClasses do: [ :eachClass |
    (eachClass inheritsFrom: TestCase) ifTrue: [ suite addTest: eachClass suite ] ].
result := suite run.
failures := result failures size.
errors := result errors size.
Stdio stdout
    nextPutAll: 'Tests run: '; nextPutAll: result runCount printString;
    nextPutAll: ', failures: '; nextPutAll: failures printString;
    nextPutAll: ', errors: '; nextPutAll: errors printString; lf; flush.
Smalltalk exit: ((failures = 0 and: [ errors = 0 ]) ifTrue: [ 0 ] ifFalse: [ 1 ])
