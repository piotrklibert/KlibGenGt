| result |
result := Smalltalk compiler evaluate: '1 + 2'.
result = 3 ifFalse: [ Smalltalk exit: 1 ].
(Smalltalk includesKey: #BaselineOfGToolkit) ifFalse: [ Smalltalk exit: 1 ].
(Smalltalk includesKey: #KlibGenGt) ifTrue: [ Smalltalk exit: 1 ].
Stdio stdout nextPutAll: 'L02 contract passed'; lf; flush.
Smalltalk exit: 0
