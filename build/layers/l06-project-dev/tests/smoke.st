(Smalltalk includesKey: #KlibGenGt) ifFalse: [ Smalltalk exit: 1 ].
KlibGenGt projectName = 'KlibGenGt' ifFalse: [ Smalltalk exit: 1 ].
Stdio stdout nextPutAll: 'Smoke check passed: KlibGenGt loaded from exact JJ source.'; lf; flush.
Smalltalk exit: 0
