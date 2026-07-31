| expectedProfile expectedDigest |
expectedProfile := Smalltalk os environment at: 'KLIBGEN_PROFILE'.
expectedDigest := Smalltalk os environment at: 'KLIBGEN_MANIFESTS_DIGEST'.
(Smalltalk includesKey: #KlibGenBuildMetadata) ifFalse: [ Smalltalk exit: 1 ].
KlibGenBuildMetadata profile = expectedProfile ifFalse: [ Smalltalk exit: 1 ].
KlibGenBuildMetadata digest = expectedDigest ifFalse: [ Smalltalk exit: 1 ].
(KlibGenBuildMetadata manifestForLayer: 'L04') ifNil: [ Smalltalk exit: 1 ].
(Smalltalk compiler evaluate: '40 + 2') = 42 ifFalse: [ Smalltalk exit: 1 ].
(expectedProfile = 'GUI' and: [ (Smalltalk includesKey: #BlSpace) not ]) ifTrue: [ Smalltalk exit: 1 ].
Stdio stdout nextPutAll: 'L05 contract passed for '; nextPutAll: expectedProfile; lf; flush.
Smalltalk exit: 0
