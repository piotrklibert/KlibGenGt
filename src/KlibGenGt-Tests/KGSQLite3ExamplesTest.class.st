"
SUnit coverage for SQLite3 loading, native-library diagnostics, and database operations.

- Slots
  - none
- Public API
  - none; test selectors are invoked by SUnit and document expected SQLite3 behavior.
"
Class {
	#name : 'KGSQLite3ExamplesTest',
	#superclass : 'TestCase',
	#category : 'KlibGenGt-Tests-DB',
	#package : 'KlibGenGt-Tests'
}

{ #category : 'tests' }
KGSQLite3ExamplesTest >> testFileRoundTrip [
	| rows |
	rows := KGSQLite3Examples new fileRoundTrip.
	self assert: rows size equals: 1
]

{ #category : 'tests' }
KGSQLite3ExamplesTest >> testInMemoryRoundTrip [
	| rows |
	rows := KGSQLite3Examples new inMemoryRoundTrip.
	self assert: rows size equals: 2
]

{ #category : 'tests' }
KGSQLite3ExamplesTest >> testLibraryDiagnostics [
	| diagnostics |
	diagnostics := KGSQLite3Examples new libraryDiagnostics.
	self deny: (diagnostics at: #libraryPath) isEmpty.
	self deny: (diagnostics at: #libraryVersion) isEmpty
]

{ #category : 'tests' }
KGSQLite3ExamplesTest >> testOpenAndCloseInMemory [
	| state |
	state := KGSQLite3Examples new openAndCloseInMemory.
	self assert: (state at: #opened).
	self assert: (state at: #closed)
]
