"
Staged SQLite3 examples for verifying the external library and common database operations.

- Slots
  - none
- Public API
  - {{gtMethod:KGSQLite3Examples>>#libraryDiagnostics}}
    Resolve the native SQLite library and report its runtime properties.
  - {{gtMethod:KGSQLite3Examples>>#openAndCloseInMemory}}
    Open and close an in-memory connection without executing SQL.
  - {{gtMethod:KGSQLite3Examples>>#inMemoryRoundTrip}}
    Create, populate, and query an in-memory database with bound parameters.
  - {{gtMethod:KGSQLite3Examples>>#fileRoundTrip}}
    Exercise a file-backed database under the project's ignored `tmp` directory.
"
Class {
	#name : 'KGSQLite3Examples',
	#superclass : 'Object',
	#category : 'KlibGenGt-DB',
	#package : 'KlibGenGt-DB'
}

{ #category : 'examples - diagnostics' }
KGSQLite3Examples >> libraryDiagnostics [
	<gtExample>
	<return: #(OrderedDictionary<Symbol, Any>)>
	| library |
	library := SQLite3Library current.
	^ OrderedDictionary new
		at: #platform put: Smalltalk os class name;
		at: #wordSize put: Smalltalk vm wordSize;
		at: #libraryPath put: library libraryName;
		at: #libraryVersion put: library libraryVersion;
		at: #threadsafe put: SQLite3Connection isThreadsafe;
		yourself
]

{ #category : 'examples - diagnostics' }
KGSQLite3Examples >> openAndCloseInMemory [
	<gtExample>
	<return: #(OrderedDictionary<Symbol, Any>)>
	| connection result |
	connection := SQLite3Connection memory.
	[
		connection open.
		self assert: connection isOpen.
		result := OrderedDictionary new
			at: #filename put: connection filename;
			at: #opened put: connection isOpen;
			yourself
	] ensure: [ self closeConnection: connection ].
	self assert: connection isOpen not.
	result at: #closed put: connection isOpen not.
	^ result
]

{ #category : 'examples - operations' }
KGSQLite3Examples >> inMemoryRoundTrip [
	<gtExample>
	<return: #(Array<(Dictionary<String, Any>)>)>
	| connection rows |
	connection := SQLite3Connection memory.
	[
		connection open.
		connection basicExecute:
			'CREATE TABLE person (id INTEGER PRIMARY KEY, name TEXT NOT NULL, age INTEGER NOT NULL)'.
		self
			execute: 'INSERT INTO person (id, name, age) VALUES (?, ?, ?)'
			with: #( 1 'Ada' 36 )
			on: connection.
		self
			execute: 'INSERT INTO person (id, name, age) VALUES (?, ?, ?)'
			with: #( 2 'Grace' 42 )
			on: connection.
		rows := self
			query: 'SELECT id, name, age FROM person ORDER BY id'
			with: #()
			on: connection
	] ensure: [ self closeConnection: connection ].
	self assert: rows size equals: 2.
	self assert: (rows first at: 'name') equals: 'Ada'.
	self assert: (rows second at: 'age') equals: 42.
	^ rows
]

{ #category : 'examples - operations' }
KGSQLite3Examples >> fileRoundTrip [
	<gtExample>
	<return: #(Array<(Dictionary<String, Any>)>)>
	| path connection rows |
	path := FileSystem workingDirectory / 'tmp'
		/ ('kg-sqlite3-example-' , UUID new asString , '.db').
	path parent ensureCreateDirectory.
	path exists ifTrue: [ path delete ].
	connection := SQLite3Connection on: path fullName.
	[
		connection open.
		connection basicExecute:
			'CREATE TABLE sample (id INTEGER PRIMARY KEY, value TEXT NOT NULL)'.
		self
			execute: 'INSERT INTO sample (id, value) VALUES (?, ?)'
			with: #( 1 'stored on disk' )
			on: connection.
		rows := self
			query: 'SELECT id, value FROM sample'
			with: #()
			on: connection
	] ensure: [
		self closeConnection: connection.
		path exists ifTrue: [ path delete ] ].
	self assert: rows size equals: 1.
	self assert: (rows first at: 'value') equals: 'stored on disk'.
	^ rows
]

{ #category : 'private - resources' }
KGSQLite3Examples >> closeConnection: aConnection [
	aConnection isOpen
		ifTrue: [ aConnection forceClose ]
		ifFalse: [ aConnection close ]
]

{ #category : 'private - execution' }
KGSQLite3Examples >> execute: sqlString with: parameters on: connection [
	| statement cursor |
	statement := connection prepare: sqlString.
	[
		cursor := statement execute: parameters.
		self assert: cursor rows isEmpty
	] ensure: [ statement finalize ]
]

{ #category : 'private - execution' }
KGSQLite3Examples >> query: sqlString with: parameters on: connection [
	| statement cursor |
	statement := connection prepare: sqlString.
	^	[
		cursor := statement execute: parameters.
		(cursor rows collect: [ :row | row asDictionary ]) asArray
	] ensure: [ statement finalize ]
]
