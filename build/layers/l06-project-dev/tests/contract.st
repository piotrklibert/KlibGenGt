| report resultsPath failures errors |
(Smalltalk includesKey: #KlibGenGt) ifFalse: [ Smalltalk exit: 1 ].
KlibGenGt projectName = 'KlibGenGt' ifFalse: [ Smalltalk exit: 1 ].
report := KGTestTool new runAllProjectTests.
resultsPath := Smalltalk os environment at: 'KLIBGEN_TEST_RESULTS_PATH' ifAbsent: [ nil ].
resultsPath ifNotNil: [
    resultsPath asFileReference parent ensureCreateDirectory.
    resultsPath asFileReference writeStreamDo: [ :stream |
        stream nextPutAll: (STONJSON toString: report); lf ] ].
failures := report at: 'failureCount'.
errors := report at: 'errorCount'.
Stdio stdout
    nextPutAll: 'Tests run: '; nextPutAll: (report at: 'runCount') printString;
    nextPutAll: ', failures: '; nextPutAll: failures printString;
    nextPutAll: ', errors: '; nextPutAll: errors printString; lf; flush.
(report at: 'tests') do: [ :test |
    (test at: 'status') = 'passed' ifFalse: [
        Stdio stdout
            nextPutAll: (test at: 'status') asUppercase; space;
            nextPutAll: (test at: 'class'); nextPutAll: '>>'; nextPutAll: (test at: 'selector').
        (test at: 'exception') ifNotNil: [ :exception |
            Stdio stdout nextPutAll: ': '; nextPutAll: (exception at: 'class');
                nextPutAll: ': '; nextPutAll: (exception at: 'message') ].
        Stdio stdout lf; flush ] ].
Smalltalk exit: ((failures = 0 and: [ errors = 0 ]) ifTrue: [ 0 ] ifFalse: [ 1 ])
