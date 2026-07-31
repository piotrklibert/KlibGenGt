"
Search loaded Lepiter databases and export individual pages as Markdown for CLI clients.

- Slots
  - none
- Public API
  - {{gtMethod:KGLepiterTool>>#search:}}
    Search page titles or page text across all loaded or selected databases.
  - {{gtMethod:KGLepiterTool>>#export:}}
    Resolve one page by UID or exact title and answer its Markdown representation.
"
Class {
	#name : 'KGLepiterTool',
	#superclass : 'Object',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'private - databases' }
KGLepiterTool >> databaseName: aDatabase [
	^ aDatabase databaseName ifNil: [ aDatabase printString copyUpTo: $: ]
]

{ #category : 'private - databases' }
KGLepiterTool >> databasesFor: aRequest [
	| databases names |
	databases := LeDatabasesRegistry uniqueInstance defaultLogicalDatabase databases.
	names := aRequest at: 'databases' ifAbsent: [ #() ].
	names isEmpty ifTrue: [ ^ databases ].
	^ names collect: [ :name |
		databases
			detect: [ :database | (self databaseName: database) = name ]
			ifNone: [ self error: 'Lepiter database not found: ' , name ] ]
]

{ #category : 'exporting' }
KGLepiterTool >> export: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, String>)>
	| uid title matches |
	uid := aRequest at: 'uid' ifAbsent: [ nil ].
	title := aRequest at: 'title' ifAbsent: [ nil ].
	(uid isNil = title isNil) ifTrue: [ self error: 'provide exactly one of uid or title' ].
	matches := OrderedCollection new.
	(self databasesFor: aRequest) do: [ :database |
		database pagesDo: [ :page |
			((uid notNil and: [ page uidString = uid ])
				or: [ title notNil and: [ page title = title ] ]) ifTrue: [
				matches add: { database. page } ] ] ].
	matches isEmpty ifTrue: [ self error: 'Lepiter page not found' ].
	matches size > 1 ifTrue: [
		self error: 'Lepiter page is ambiguous: ' ,
			(', ' join: (matches collect: [ :each |
				(self databaseName: each first) , '/' , each second uidString ])) ].
	^ OrderedDictionary new
		at: 'database' put: (self databaseName: matches first first);
		at: 'uid' put: matches first second uidString;
		at: 'title' put: matches first second title;
		at: 'text' put: matches first second asMarkdownPage;
		yourself
]

{ #category : 'private - searching' }
KGLepiterTool >> previewFor: aPage [
	| text |
	text := aPage asMarkdownPage copyReplaceAll: String lf with: ' '.
	^ text first: (240 min: text size)
]

{ #category : 'searching' }
KGLepiterTool >> search: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| query searchIn limit results |
	query := aRequest at: 'query'.
	searchIn := aRequest at: 'in' ifAbsent: [ 'text' ].
	limit := aRequest at: 'limit' ifAbsent: [ 100 ].
	(#('text' 'title') includes: searchIn)
		ifFalse: [ self error: 'Lepiter search mode must be text or title' ].
	results := OrderedCollection new.
	(self databasesFor: aRequest) do: [ :database |
		| pages |
		pages := ((searchIn = 'title'
			ifTrue: [ database asyncPagesForWord: query ]
			ifFalse: [ database asyncPagesContainingText: query ]) toArray wait).
		pages do: [ :page |
			results add: (OrderedDictionary new
				at: 'database' put: (self databaseName: database);
				at: 'uid' put: page uidString;
				at: 'title' put: page title;
				at: 'preview' put: (self previewFor: page);
				yourself) ] ].
	results size > limit ifTrue: [ results := results first: limit ].
	^ OrderedDictionary new
		at: 'query' put: query;
		at: 'results' put: results asArray;
		at: 'count' put: results size;
		yourself
]
