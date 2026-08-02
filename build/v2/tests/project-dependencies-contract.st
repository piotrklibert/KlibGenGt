| connection version |
(Smalltalk includesKey: #SQLite3Connection) ifFalse: [ Smalltalk exit: 1 ].
(Smalltalk includesKey: #SQLite3Library) ifFalse: [ Smalltalk exit: 1 ].
(Smalltalk includesKey: #KlibGenGt) ifTrue: [ Smalltalk exit: 1 ].
version := SQLite3Library current libraryVersion.
version isEmpty ifTrue: [ Smalltalk exit: 1 ].
connection := SQLite3Connection memory.
[ connection open. connection isOpen ifFalse: [ Smalltalk exit: 1 ] ] ensure: [ connection isOpen ifTrue: [ connection forceClose ] ].
Stdio stdout nextPutAll: 'Dependency contract passed with SQLite '; nextPutAll: version; lf; flush.
Smalltalk exit: 0
