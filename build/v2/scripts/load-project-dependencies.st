| repository |
repository := Smalltalk os environment at: 'KLIBGEN_SQLITE_REPOSITORY'.
Metacello new baseline: 'SQLite3'; repository: repository; onConflictUseIncoming; load: 'Core'.
Stdio stdout nextPutAll: 'Loaded SQLite3 dependency from '; nextPutAll: repository; lf; flush.
Smalltalk snapshot: true andQuit: true
