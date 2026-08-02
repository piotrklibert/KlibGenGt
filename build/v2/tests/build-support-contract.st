(Smalltalk includesKey: #KGBuildProvenance) ifFalse: [ Smalltalk exit: 1 ].
Stdio stdout nextPutAll: 'V0.2 build support contract passed'; lf; flush.
Smalltalk exit: 0
