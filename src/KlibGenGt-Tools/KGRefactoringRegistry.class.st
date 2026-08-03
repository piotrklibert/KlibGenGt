"
Own stable refactoring adapters and report the broader installed Pharo inventory.

- Slots
  - `adapters` (`#(Dictionary<String, KGRefactoringAdapter>)`, `registry`) - Stable identifier-to-adapter map.
- Public API
  - {{gtMethod:KGRefactoringRegistry>>#adapterNamed:}}
    Resolve a supported stable refactoring identifier.
  - {{gtMethod:KGRefactoringRegistry>>#adapters}}
    Answer all stable adapters sorted by identifier.
  - {{gtMethod:KGRefactoringRegistry>>#applicable:}}
    Report candidate adapters and missing arguments for a target request.
  - {{gtMethod:KGRefactoringRegistry>>#catalog}}
    Answer supported adapters and installed framework transformations.
  - {{gtMethod:KGRefactoringRegistry>>#describe:}}
    Answer one supported adapter description.
"
Class {
	#name : 'KGRefactoringRegistry',
	#superclass : 'Object',
	#instVars : [
		'adapters'
	],
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'accessing' }
KGRefactoringRegistry >> adapterNamed: anIdentifier [
	<arg: #anIdentifier type: #String>
	<return: #KGRefactoringAdapter>
	^ adapters at: anIdentifier ifAbsent: [ self error: 'unsupported refactoring: ', anIdentifier ]
]

{ #category : 'accessing' }
KGRefactoringRegistry >> adapters [
	<return: #(Array<KGRefactoringAdapter>)>
	^ (adapters values sorted: [ :left :right | left identifier < right identifier ]) asArray
]

{ #category : 'querying' }
KGRefactoringRegistry >> applicable: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| target kind candidates |
	target := aRequest at: 'target' ifAbsent: [ Dictionary new ].
	kind := target at: 'kind' ifAbsent: [ nil ].
	candidates := self adapters
		select: [ :adapter | kind isNil or: [ adapter targetKind = kind ] ]
		thenCollect: [ :adapter |
			| supplied missing |
			supplied := aRequest at: 'arguments' ifAbsent: [ Dictionary new ].
			missing := adapter requiredArguments reject: [ :name | supplied includesKey: name ].
			adapter descriptor copy
				at: 'applicability' put: (missing isEmpty ifTrue: [ 'ready-for-preview' ] ifFalse: [ 'needs-arguments' ]);
				at: 'missingArguments' put: missing;
				yourself ].
	^ OrderedDictionary new at: 'candidates' put: candidates asArray; yourself
]

{ #category : 'querying' }
KGRefactoringRegistry >> catalog [
	<return: #(Dictionary<String, Any>)>
	| installed |
	installed := (RBAbstractTransformation allSubclasses
		sorted: [ :left :right | left name < right name ]) collect: [ :class |
		OrderedDictionary new
			at: 'class' put: class name asString;
			at: 'package' put: class package name asString;
			at: 'superclass' put: class superclass name asString;
			at: 'status' put: 'observed';
			yourself ].
	^ OrderedDictionary new
		at: 'supported' put: (self adapters collect: #descriptor);
		at: 'installed' put: installed asArray;
		yourself
]

{ #category : 'querying' }
KGRefactoringRegistry >> describe: anIdentifier [
	<arg: #anIdentifier type: #String>
	<return: #(Dictionary<String, Any>)>
	^ (self adapterNamed: anIdentifier) descriptor
]

{ #category : 'initialization' }
KGRefactoringRegistry >> initialize [
	<return: #KGRefactoringRegistry>
	super initialize.
	adapters := Dictionary new.
	{
		KGClassRenameRefactoringAdapter new.
		KGMethodRenameRefactoringAdapter new.
		KGInstanceVariableRenameRefactoringAdapter new.
		KGMethodMoveRefactoringAdapter new.
		KGMethodExtractRefactoringAdapter new.
		KGParameterAddRefactoringAdapter new.
		KGParameterRemoveRefactoringAdapter new.
		KGParameterRenameRefactoringAdapter new.
		KGASTRewriteRefactoringAdapter new
	} do: [ :adapter | adapters at: adapter identifier put: adapter ].
	^ self
]
