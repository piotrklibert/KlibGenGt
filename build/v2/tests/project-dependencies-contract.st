| connection version |
(Smalltalk includesKey: #SQLite3Connection) ifFalse: [ Smalltalk exit: 1 ].
(Smalltalk includesKey: #SQLite3Library) ifFalse: [ Smalltalk exit: 1 ].
(Smalltalk includesKey: #NeoJSONReader) ifFalse: [ Smalltalk exit: 1 ].
(Smalltalk includesKey: #NeoJSONWriter) ifFalse: [ Smalltalk exit: 1 ].
(Smalltalk includesKey: #JSONSchema) ifFalse: [ Smalltalk exit: 1 ].
(Smalltalk includesKey: #KlibGenGt) ifTrue: [ Smalltalk exit: 1 ].
version := SQLite3Library current libraryVersion.
version isEmpty ifTrue: [ Smalltalk exit: 1 ].
connection := SQLite3Connection memory.
[ connection open. connection isOpen ifFalse: [ Smalltalk exit: 1 ] ] ensure: [ connection isOpen ifTrue: [ connection forceClose ] ].
Stdio stdout nextPutAll: 'Dependency contract passed with SQLite '; nextPutAll: version; nextPutAll: ', NeoJSON, and JSONSchema'; lf; flush.
Smalltalk exit: 0
