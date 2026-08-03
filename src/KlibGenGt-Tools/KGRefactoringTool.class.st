"
Expose catalog, applicability, conflict-free preview, and staged application of refactorings.

- Slots
  - `registry` (`#KGRefactoringRegistry`, `registry`) - Curated adapter registry.
- Public API
  - {{gtMethod:KGRefactoringTool>>#applicable:}}
    Report candidate refactorings for a structured target.
  - {{gtMethod:KGRefactoringTool>>#apply:}}
    Recompute an expected plan and export it to named staging.
  - {{gtMethod:KGRefactoringTool>>#catalog:}}
    Report supported adapters and observed framework transformations.
  - {{gtMethod:KGRefactoringTool>>#describe:}}
    Describe one stable adapter.
  - {{gtMethod:KGRefactoringTool>>#preview:}}
    Apply only in the disposable image and return exact Tonel changes.
"
Class {
	#name : 'KGRefactoringTool',
	#superclass : 'Object',
	#instVars : [
		'registry'
	],
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'querying' }
KGRefactoringTool >> applicable: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	^ self canonicalObjectFor: (registry applicable: aRequest)
]

{ #category : 'executing' }
KGRefactoringTool >> apply: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	^ self plan: aRequest exporting: true
]

{ #category : 'private - serialization' }
KGRefactoringTool >> canonicalObjectFor: anObject [
	<arg: #anObject type: #Any>
	<return: #Any>
	(anObject isDictionary) ifTrue: [
		| ordered |
		ordered := OrderedDictionary new.
		anObject keys sorted do: [ :key |
			ordered
				at: (self canonicalObjectFor: key)
				put: (self canonicalObjectFor: (anObject at: key)) ].
		^ ordered ].
	((anObject isArray) or: [ anObject isKindOf: OrderedCollection ]) ifTrue: [
		^ (anObject collect: [ :each | self canonicalObjectFor: each ]) asArray ].
	anObject isString ifTrue: [ ^ anObject copy ].
	^ anObject
]

{ #category : 'querying' }
KGRefactoringTool >> catalog: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	^ self canonicalObjectFor: registry catalog
]

{ #category : 'private - changes' }
KGRefactoringTool >> changeCount: aChange [
	<arg: #aChange type: #RBRefactoryChange>
	<return: #Integer>
	| children |
	children := (aChange respondsTo: #changes)
		ifTrue: [ aChange changes reject: [ :child | child == aChange ] ]
		ifFalse: [ #() ].
	^ 1 + (children sum: [ :child | self changeCount: child ])
]

{ #category : 'private - changes' }
KGRefactoringTool >> changeNamesIn: aChange into: names [
	<arg: #aChange type: #RBRefactoryChange>
	<arg: #names type: #(OrderedCollection<String>)>
	<return: #(OrderedCollection<String>)>
	(aChange respondsTo: #changeClassName) ifTrue: [
		[ names add: aChange changeClassName asString ] on: Error do: [ :error | error return ] ].
	(aChange respondsTo: #changes) ifTrue: [
		aChange changes do: [ :child |
			child == aChange ifFalse: [ self changeNamesIn: child into: names ] ] ].
	^ names
]

{ #category : 'private - serialization' }
KGRefactoringTool >> changeRecordFor: aChange [
	<arg: #aChange type: #RBRefactoryChange>
	<return: #(Dictionary<String, Any>)>
	| record children |
	record := OrderedDictionary new
		at: 'kind' put: aChange class name asString;
		at: 'summary' put: aChange displayString asString;
		yourself.
	(aChange respondsTo: #changeClassName) ifTrue: [
		[ record at: 'class' put: aChange changeClassName asString ] on: Error do: [ :error | error return ] ].
	children := (aChange respondsTo: #changes)
		ifTrue: [ aChange changes reject: [ :child | child == aChange ] ]
		ifFalse: [ #() ].
	children ifNotEmpty: [ record at: 'children' put: (children collect: [ :child | self changeRecordFor: child ]) asArray ].
	^ record
]

{ #category : 'querying' }
KGRefactoringTool >> describe: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	^ self canonicalObjectFor: (registry describe: (aRequest at: 'refactoring'))
]

{ #category : 'private - files' }
KGRefactoringTool >> filesAt: aRoot [
	<arg: #aRoot type: #FileReference>
	<return: #(Dictionary<String, String>)>
	| files |
	files := Dictionary new.
	aRoot exists ifFalse: [ ^ files ].
	aRoot allChildren
		select: [ :file | file isFile and: [ file extension = 'st' ] ]
		thenDo: [ :file |
			files at: (file relativeTo: aRoot) pathString put: file contents ].
	^ files
]

{ #category : 'private - serialization' }
KGRefactoringTool >> impactFor: changes tonelChanges: tonelChanges [
	<arg: #changes type: #RBRefactoryChange>
	<arg: #tonelChanges type: #(Array<(Dictionary<String, Any>)>)>
	<return: #(Dictionary<String, Integer>)>
	^ OrderedDictionary new
		at: 'semanticChanges' put: (self changeCount: changes);
		at: 'tonelFiles' put: tonelChanges size;
		at: 'tonelBytes' put: (tonelChanges sum: [ :record |
			| beforeSize afterSize |
			beforeSize := (record at: 'before') ifNil: [ 0 ] ifNotNil: [ :text | text utf8Encoded size ].
			afterSize := (record at: 'after') ifNil: [ 0 ] ifNotNil: [ :text | text utf8Encoded size ].
			beforeSize + afterSize ]);
		yourself
]

{ #category : 'initialization' }
KGRefactoringTool >> initialize [
	<return: #KGRefactoringTool>
	super initialize.
	registry := KGRefactoringRegistry new.
	^ self
]

{ #category : 'private - changes' }
KGRefactoringTool >> isProjectChangeClassName: aName [
	<arg: #aName type: #String>
	<return: #Boolean>
	| behavior |
	behavior := Smalltalk globals at: aName asSymbol ifAbsent: [ ^ true ].
	^ behavior package name beginsWith: 'KlibGenGt-'
]

{ #category : 'private - planning' }
KGRefactoringTool >> plan: aRequest exporting: shouldExport [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<arg: #shouldExport type: #Boolean>
	<return: #(Dictionary<String, Any>)>
	| adapter model refactoring warnings acknowledged generated changes names limit tonelChanges planId result commit unsafe |
	adapter := registry adapterNamed: (aRequest at: 'refactoring').
	model := GtRBNamespace new.
	refactoring := adapter buildIn: model request: aRequest.
	warnings := OrderedCollection new.
	acknowledged := aRequest at: 'acknowledgedWarnings' ifAbsent: [ #() ].
	generated := true.
	[ refactoring generateChanges ] on: RBRefactoringWarning do: [ :warning |
		| record id |
		id := self warningIdFor: warning.
		record := OrderedDictionary new
			at: 'id' put: id;
			at: 'class' put: warning class name asString;
			at: 'message' put: warning messageText;
			at: 'acknowledged' put: (acknowledged includes: id);
			yourself.
		warnings add: record.
		(acknowledged includes: id)
			ifTrue: [ warning resume ]
			ifFalse: [ generated := false. warning return ] ].
	generated ifFalse: [
		result := OrderedDictionary new
			at: 'applicable' put: false;
			at: 'status' put: 'warning';
			at: 'warnings' put: warnings asArray;
			yourself.
		^ self canonicalObjectFor: result ].
	changes := model changes.
	limit := ((aRequest at: 'limits' ifAbsent: [ Dictionary new ]) at: 'maxChanges' ifAbsent: [ 500 ]) min: 2000.
	(self changeCount: changes) > limit ifTrue: [ self error: 'refactoring change limit exceeded' ].
	names := self changeNamesIn: changes into: OrderedCollection new.
	(names anySatisfy: [ :name | (self isProjectChangeClassName: name) not ]) ifTrue: [
		self error: 'refactoring would change a class outside KlibGenGt packages' ].
	refactoring performChanges.
	tonelChanges := self tonelChanges.
	planId := self planIdFor: aRequest adapter: adapter warnings: warnings asArray tonelChanges: tonelChanges.
	shouldExport ifTrue: [
		(aRequest at: 'expect' ifAbsent: [ self error: 'refactor.apply requires expect' ]) = planId ifFalse: [
			self error: 'refactoring plan no longer matches; preview again' ] ].
	unsafe := (refactoring isKindOf: KGASTRewriteRefactoring)
		ifTrue: [ refactoring containsPatternBlocks ifTrue: [ #('ast-pattern-blocks') ] ifFalse: [ #() ] ]
		ifFalse: [ #() ].
	result := OrderedDictionary new
		at: 'applicable' put: true;
		at: 'status' put: (shouldExport ifTrue: [ 'applied' ] ifFalse: [ 'previewed' ]);
		at: 'refactoring' put: adapter descriptor;
		at: 'warnings' put: warnings asArray;
		at: 'unsafeFeatures' put: unsafe;
		at: 'staging' put: self stagingIdentity;
		at: 'impact' put: (self impactFor: changes tonelChanges: tonelChanges);
		at: 'changes' put: { self changeRecordFor: changes };
		at: 'tonelChanges' put: tonelChanges;
		at: 'planId' put: planId;
		yourself.
	(refactoring isKindOf: KGASTRewriteRefactoring) ifTrue: [ result at: 'matchCount' put: refactoring matchCount ].
	shouldExport ifTrue: [
		commit := KGSession current sourceChanges exportChanges.
		result at: 'commit' put: (commit ifNil: [ nil ] ifNotNil: [ commit id asString ]) ].
	^ self canonicalObjectFor: result
]

{ #category : 'private - identity' }
KGRefactoringTool >> planIdFor: aRequest adapter: adapter warnings: warnings tonelChanges: tonelChanges [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<arg: #adapter type: #KGRefactoringAdapter>
	<arg: #warnings type: #(Array<(Dictionary<String, Any>)>)>
	<arg: #tonelChanges type: #(Array<(Dictionary<String, Any>)>)>
	<return: #String>
	| session material normalizedRequest serialized |
	session := KGSession current.
	normalizedRequest := aRequest copy.
	normalizedRequest removeKey: 'operation' ifAbsent: [ ].
	normalizedRequest removeKey: 'expect' ifAbsent: [ ].
	material := OrderedDictionary new
		at: 'request' put: normalizedRequest;
		at: 'adapter' put: adapter identifier;
		at: 'adapterVersion' put: adapter version;
		at: 'projectKey' put: session manifest projectKey;
		at: 'stagingArea' put: (session manifest inputs at: 'stagingArea');
		at: 'stagingGeneration' put: (session manifest inputs at: 'stagingGeneration');
		at: 'stagingHeadCommit' put: session sourceChanges headCommit;
		at: 'warnings' put: (warnings collect: [ :warning | warning at: 'id' ]);
		at: 'tonelChanges' put: tonelChanges;
		yourself.
	serialized := STONJSON toString: (self canonicalObjectFor: material).
	^ 'sha256:', (SHA256 hashMessage: serialized utf8Encoded) hex
]

{ #category : 'executing' }
KGRefactoringTool >> preview: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	^ self plan: aRequest exporting: false
]

{ #category : 'private - identity' }
KGRefactoringTool >> stagingIdentity [
	<return: #(Dictionary<String, Any>)>
	| session |
	session := KGSession current.
	^ OrderedDictionary new
		at: 'name' put: (session manifest inputs at: 'stagingArea');
		at: 'generation' put: (session manifest inputs at: 'stagingGeneration');
		at: 'headCommit' put: session sourceChanges headCommit;
		yourself
]

{ #category : 'private - files' }
KGRefactoringTool >> tonelChanges [
	<return: #(Array<(Dictionary<String, Any>)>)>
	| source repository output writer before after paths records byteCount |
	source := KGSession current sourceChanges.
	repository := source sourceRepository.
	output := FileLocator temp / ('kg-refactoring-', UUID new asString).
	output ensureCreateDirectory.
	[ writer := TonelWriter on: output.
	  repository workingCopy packages
		select: [ :package | package name beginsWith: 'KlibGenGt-' ]
		thenDo: [ :package | writer writeSnapshot: (repository workingCopy snapshotForPackage: package) ].
	  before := self filesAt: source sourceRoot.
	  after := self filesAt: output.
	  paths := ((before keys, after keys) asSet select: [ :path | path beginsWith: 'KlibGenGt-' ]) asArray sorted.
	  records := OrderedCollection new.
	  byteCount := 0.
	  paths do: [ :path |
		| old new |
		old := before at: path ifAbsent: [ nil ].
		new := after at: path ifAbsent: [ nil ].
		old = new ifFalse: [
			byteCount := byteCount + (old ifNil: [ 0 ] ifNotNil: [ old utf8Encoded size ]) + (new ifNil: [ 0 ] ifNotNil: [ new utf8Encoded size ]).
			byteCount > (2 * 1024 * 1024) ifTrue: [ self error: 'refactoring Tonel result exceeds 2 MiB' ].
			records add: (OrderedDictionary new at: 'path' put: path; at: 'before' put: old; at: 'after' put: new; yourself) ] ].
	  ^ records asArray ] ensure: [ output ensureDeleteAll ]
]

{ #category : 'private - warnings' }
KGRefactoringTool >> warningIdFor: aWarning [
	<arg: #aWarning type: #RBRefactoringWarning>
	<return: #String>
	| material |
	material := aWarning class name asString, ':', aWarning messageText trimBoth.
	^ 'sha256:', (SHA256 hashMessage: material utf8Encoded) hex
]
