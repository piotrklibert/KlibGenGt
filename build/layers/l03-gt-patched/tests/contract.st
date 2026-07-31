| expected source patched |
expected := Smalltalk os environment at: 'KLIBGEN_EXPECT_GT_PATCH' ifAbsent: [ 'false' ].
source := GtWebViewLibrary class sourceCodeAt: #startUp:.
patched := source includesSubstring: 'Smalltalk isHeadless not'.
(expected = 'true' and: [ patched not ]) ifTrue: [ Smalltalk exit: 1 ].
(expected = 'false' and: [ patched ]) ifTrue: [ Smalltalk exit: 1 ].
(Smalltalk includesKey: #KlibGenGt) ifTrue: [ Smalltalk exit: 1 ].
Stdio stdout nextPutAll: 'L03 contract passed'; lf; flush.
Smalltalk exit: 0
