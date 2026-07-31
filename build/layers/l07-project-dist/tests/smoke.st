(Smalltalk includesKey: #KlibGenGt) ifFalse: [ Smalltalk exit: 1 ].
KlibGenGt projectName = 'KlibGenGt' ifFalse: [ Smalltalk exit: 1 ].
Stdio stdout nextPutAll: 'KlibGenGt DEV distribution startup passed.'; lf; flush.
Smalltalk exit: 0
