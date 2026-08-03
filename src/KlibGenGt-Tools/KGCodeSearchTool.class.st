"
Search loaded classes and methods and provide exact source definitions for CLI clients.

- Slots
  - none
- Public API
  - {{gtMethod:KGCodeSearchTool>>#search:}}
    Search classes and methods using the requested query, kind, package, and limit.
  - {{gtMethod:KGCodeSearchTool>>#classDefinition:}}
    Answer the exact definition string of one loaded class.
  - {{gtMethod:KGCodeSearchTool>>#methodSource:}}
    Answer the exact source of one instance-side or class-side method.
"
Class {
	#name : 'KGCodeSearchTool',
	#superclass : 'Object',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'accessing' }
KGCodeSearchTool >> classDefinition: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, String>)>
	| className aClass |
	className := aRequest at: 'class'.
	aClass := Smalltalk globals
		at: className asSymbol
		ifAbsent: [ self error: 'class not found: ' , className ].
	^ OrderedDictionary new
		at: 'class' put: aClass name asString;
		at: 'text' put: aClass definitionString;
		yourself
]

{ #category : 'private - searching' }
KGCodeSearchTool >> classResultsFor: query package: packageName [
	| lowered classes |
	lowered := query asLowercase.
	classes := SystemNavigation default allClassesAndTraits select: [ :aClass |
		(aClass name asString asLowercase includesSubstring: lowered)
			and: [ packageName isNil or: [ aClass package name = packageName ] ] ].
	^ (classes sorted: [ :left :right | left name < right name ]) collect: [ :aClass |
		OrderedDictionary new
			at: 'kind' put: 'class';
			at: 'class' put: aClass name asString;
			at: 'package' put: aClass package name asString;
			yourself ]
]

{ #category : 'private - accessing' }
KGCodeSearchTool >> classSideFor: aRequest [
	| className aClass side |
	className := aRequest at: 'class'.
	aClass := Smalltalk globals
		at: className asSymbol
		ifAbsent: [ self error: 'class not found: ' , className ].
	side := aRequest at: 'side' ifAbsent: [ 'instance' ].
	(side = 'instance' or: [ side = 'class' ])
		ifFalse: [ self error: 'side must be instance or class' ].
	^ side = 'class' ifTrue: [ aClass class ] ifFalse: [ aClass ]
]

{ #category : 'private - searching' }
KGCodeSearchTool >> methodResultsFor: query package: packageName [
	| methods |
	methods := query gtSubstringMatch contents.
	packageName ifNotNil: [
		methods := methods select: [ :method | method package name = packageName ] ].
	^ methods collect: [ :method |
		OrderedDictionary new
			at: 'kind' put: 'method';
			at: 'class' put: method methodClass instanceSide name asString;
			at: 'side' put: (method methodClass isMeta ifTrue: [ 'class' ] ifFalse: [ 'instance' ]);
			at: 'selector' put: method selector asString;
			at: 'protocol' put: method protocolName asString;
			at: 'package' put: method package name asString;
			yourself ]
]

{ #category : 'accessing' }
KGCodeSearchTool >> methodSource: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, String>)>
	| classSide selector method |
	classSide := self classSideFor: aRequest.
	selector := (aRequest at: 'selector') asSymbol.
	method := classSide
		compiledMethodAt: selector
		ifAbsent: [ self error: 'method not found: ' , classSide name , '>>#' , selector ].
	^ OrderedDictionary new
		at: 'class' put: classSide instanceSide name asString;
		at: 'side' put: (classSide isMeta ifTrue: [ 'class' ] ifFalse: [ 'instance' ]);
		at: 'selector' put: selector asString;
		at: 'text' put: method sourceCode;
		yourself
]

{ #category : 'searching' }
KGCodeSearchTool >> search: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| query kind packageName limit results |
	query := aRequest at: 'query'.
	kind := aRequest at: 'kind' ifAbsent: [ 'all' ].
	packageName := aRequest at: 'package' ifAbsent: [ nil ].
	limit := aRequest at: 'limit' ifAbsent: [ 100 ].
	(#('all' 'class' 'method') includes: kind)
		ifFalse: [ self error: 'kind must be all, class, or method' ].
	results := OrderedCollection new.
	(kind = 'all' or: [ kind = 'class' ]) ifTrue: [
		results addAll: (self classResultsFor: query package: packageName) ].
	(kind = 'all' or: [ kind = 'method' ]) ifTrue: [
		results addAll: (self methodResultsFor: query package: packageName) ].
	results size > limit ifTrue: [ results := results first: limit ].
	^ OrderedDictionary new
		at: 'query' put: query;
		at: 'results' put: results asArray;
		at: 'count' put: results size;
		yourself
]
