"
Facade for package-aware loaded-image code search, exact source retrieval, metadata, and navigation.

- Slots
  - none
- Public API
  - {{gtMethod:KGCodeSearchTool>>#search:}}
    Search loaded classes and methods by field and match mode within a package scope.
  - {{gtMethod:KGCodeSearchTool>>#classDefinition:}}
    Answer an exact class definition even when its package is outside the selected scope.
  - {{gtMethod:KGCodeSearchTool>>#methodSource:}}
    Answer an exact method source even when its package is outside the selected scope.
  - {{gtMethod:KGCodeSearchTool>>#classMethods:}}
    Dump normalized local methods and requested inherited, trait, or extension methods.
  - {{gtMethod:KGCodeSearchTool>>#classInfo:}}
    Describe a loaded class, its hierarchy, state, protocols, and overrides.
  - {{gtMethod:KGCodeSearchTool>>#packageInfo:}}
    Describe one loaded package and its dependency relationships.
  - {{gtMethod:KGCodeSearchTool>>#packageSets:}}
    Resolve named loaded-package universes.
  - {{gtMethod:KGCodeSearchTool>>#implementors:}}
    Find package-aware implementors of an exact selector.
  - {{gtMethod:KGCodeSearchTool>>#senders:}}
    Find navigation candidates whose ASTs actually send an exact selector.
  - {{gtMethod:KGCodeSearchTool>>#references:}}
    Find package-aware class, global, symbol, or string references.
  - {{gtMethod:KGCodeSearchTool>>#pragmas:}}
    Find methods carrying an exact pragma selector.
"
Class {
	#name : 'KGCodeSearchTool',
	#superclass : 'Object',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'private - methods' }
KGCodeSearchTool >> addMethodsOf: aBehavior classification: classification origin: origin to: records seen: seen protocol: protocol source: includeSource [
	aBehavior methods do: [ :method |
		| identity |
		identity := { method methodClass. method selector }.
		((seen includes: identity) not and: [
			method package = origin package and: [ self method: method matchesProtocol: protocol ] ]) ifTrue: [
			seen add: identity.
			records add: (self methodRecord: method classification: classification origin: origin includeSource: includeSource) ] ]
]

{ #category : 'private - classes' }
KGCodeSearchTool >> allClasses [
	^ SystemNavigation default allClassesAndTraits
]

{ #category : 'private - methods' }
KGCodeSearchTool >> allMethods [
	^ RPackageOrganizer default packages flatCollect: #methods
]

{ #category : 'accessing' }
KGCodeSearchTool >> classDefinition: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| aClass record scope |
	aClass := self classNamedFrom: aRequest.
	scope := KGCodePackageScope forRequest: aRequest.
	record := OrderedDictionary new
		at: 'class' put: aClass name asString;
		at: 'package' put: aClass package name asString;
		at: 'text' put: aClass definitionString;
		yourself.
	^ self exactResponse: record scope: scope
]

{ #category : 'accessing' }
KGCodeSearchTool >> classInfo: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| aClass scope supers directSubs allSubs localSelectors inheritedOverrides overriddenBy protocols traits record |
	aClass := self classNamedFrom: aRequest.
	scope := KGCodePackageScope forRequest: aRequest.
	supers := OrderedCollection new.
	aClass allSuperclassesDo: [ :each | supers add: each name asString ].
	directSubs := aClass subclasses collect: [ :each | each name asString ].
	allSubs := aClass allSubclasses collect: [ :each | each name asString ].
	localSelectors := aClass selectors asSet.
	inheritedOverrides := localSelectors select: [ :selector |
		aClass superclass notNil and: [ (aClass superclass lookupSelector: selector) notNil ] ].
	overriddenBy := OrderedCollection new.
	aClass subclasses do: [ :subclass |
		(subclass selectors intersection: localSelectors) do: [ :selector |
			overriddenBy add: (OrderedDictionary new
				at: 'class' put: subclass name asString;
				at: 'selector' put: selector asString;
				yourself) ] ].
	protocols := ((aClass methods collect: [ :method | method protocolName asString ]) asSet asArray sorted).
	traits := aClass traitComposition traits collect: [ :each | each name asString ].
	record := OrderedDictionary new
		at: 'class' put: aClass name asString;
		at: 'package' put: aClass package name asString;
		at: 'definition' put: aClass definitionString;
		at: 'comment' put: aClass comment;
		at: 'superclasses' put: supers asArray;
		at: 'directSubclasses' put: directSubs asArray sorted;
		at: 'allSubclasses' put: allSubs asArray sorted;
		at: 'traits' put: traits asArray sorted;
		at: 'slots' put: (aClass slots collect: [ :slot |
			OrderedDictionary new at: 'name' put: slot name asString; at: 'kind' put: slot class name asString; yourself ]) asArray;
		at: 'classVariables' put: ((aClass classVariables collect: [ :each | each name asString ]) asArray sorted);
		at: 'sharedPools' put: ((aClass sharedPools collect: [ :each | each name asString ]) asArray sorted);
		at: 'methodCount' put: aClass methods size;
		at: 'classMethodCount' put: aClass class methods size;
		at: 'protocols' put: protocols;
		at: 'overrides' put: ((inheritedOverrides collect: #asString) asArray sorted);
		at: 'overriddenBy' put: ((overriddenBy sorted: [ :a :b |
			(a at: 'class') , String cr , (a at: 'selector') < ((b at: 'class') , String cr , (b at: 'selector')) ]) asArray);
		yourself.
	^ self exactResponse: record scope: scope
]

{ #category : 'accessing' }
KGCodeSearchTool >> classMethods: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| aClass scope side protocol includeInherited includeExtensions includeTraits limit records seen localPackage rootOutside |
	aClass := self classNamedFrom: aRequest.
	scope := KGCodePackageScope forRequest: aRequest.
	side := aRequest at: 'side' ifAbsent: [ 'both' ].
	(#('both' 'instance' 'class') includes: side) ifFalse: [ self error: 'side must be both, instance, or class' ].
	protocol := aRequest at: 'protocol' ifAbsent: [ nil ].
	includeInherited := aRequest at: 'includeInherited' ifAbsent: [ false ].
	includeExtensions := aRequest at: 'includeExtensions' ifAbsent: [ false ].
	includeTraits := aRequest at: 'includeTraits' ifAbsent: [ false ].
	limit := aRequest at: 'limit' ifAbsent: [ 500 ].
	records := OrderedCollection new.
	seen := Set new.
	localPackage := aClass package name asString.
	(side = 'both' or: [ side = 'instance' ]) ifTrue: [
		self addMethodsOf: aClass classification: 'local' origin: aClass to: records seen: seen protocol: protocol source: true ].
	(side = 'both' or: [ side = 'class' ]) ifTrue: [
		self addMethodsOf: aClass class classification: 'local' origin: aClass class to: records seen: seen protocol: protocol source: true ].
	includeInherited ifTrue: [
		(side = 'both' or: [ side = 'instance' ]) ifTrue: [
			aClass allSuperclassesDo: [ :each |
				(scope includesPackageName: each package name asString) ifTrue: [
					self addMethodsOf: each classification: 'inherited' origin: each to: records seen: seen protocol: protocol source: true ] ] ].
		(side = 'both' or: [ side = 'class' ]) ifTrue: [
			aClass class allSuperclassesDo: [ :each |
				(scope includesPackageName: each package name asString) ifTrue: [
					self addMethodsOf: each classification: 'inherited' origin: each to: records seen: seen protocol: protocol source: true ] ] ] ].
	includeTraits ifTrue: [
		aClass traitComposition traits do: [ :trait |
			(scope includesPackageName: trait package name asString) ifTrue: [
				self addMethodsOf: trait classification: 'trait' origin: trait to: records seen: seen protocol: protocol source: true ] ] ].
	includeExtensions ifTrue: [
		RPackageOrganizer default packages do: [ :package |
			(scope includesPackageName: package name asString) ifTrue: [
				(side = 'both' or: [ side = 'instance' ]) ifTrue: [
					(package extensionMethodsForClass: aClass) do: [ :method |
						(self method: method matchesProtocol: protocol) ifTrue: [
							records add: (self methodRecord: method classification: 'extension' origin: aClass includeSource: true) ] ] ].
				(side = 'both' or: [ side = 'class' ]) ifTrue: [
					(package extensionMethodsForClass: aClass class) do: [ :method |
						(self method: method matchesProtocol: protocol) ifTrue: [
							records add: (self methodRecord: method classification: 'extension' origin: aClass class includeSource: true) ] ] ] ] ] ].
	records := records sorted: [ :a :b | self methodRecord: a precedes: b ].
	rootOutside := (scope includesPackageName: localPackage) not.
	^ OrderedDictionary new
		at: 'class' put: aClass name asString;
		at: 'scope' put: scope summary;
		at: 'rootOutsideScope' put: rootOutside;
		at: 'count' put: (limit min: records size);
		at: 'total' put: records size;
		at: 'truncated' put: (0 max: records size - limit);
		at: 'methods' put: (records first: (limit min: records size)) asArray;
		yourself
]

{ #category : 'private - classes' }
KGCodeSearchTool >> classNamedFrom: aRequest [
	| className |
	className := aRequest at: 'class'.
	^ Smalltalk globals
		at: className asSymbol
		ifAbsent: [ self error: 'class not found: ' , className ]
]

{ #category : 'private - methods' }
KGCodeSearchTool >> classSideFor: aRequest [
	| aClass side |
	aClass := self classNamedFrom: aRequest.
	side := aRequest at: 'side' ifAbsent: [ 'instance' ].
	(side = 'instance' or: [ side = 'class' ]) ifFalse: [ self error: 'side must be instance or class' ].
	^ side = 'class' ifTrue: [ aClass class ] ifFalse: [ aClass ]
]

{ #category : 'private - responses' }
KGCodeSearchTool >> exactResponse: record scope: scope [
	^ OrderedDictionary new
		at: 'scope' put: scope summary;
		at: 'rootOutsideScope' put: (scope includesPackageName: (record at: 'package')) not;
		addAll: record;
		yourself
]

{ #category : 'navigation' }
KGCodeSearchTool >> implementors: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| selector records |
	selector := (aRequest at: 'selector') asSymbol.
	records := (SystemNavigation default allImplementorsOf: selector) collect: [ :method |
		self methodRecord: method classification: 'local' origin: method methodClass includeSource: false ].
	^ self navigationResponseFor: records request: aRequest
]

{ #category : 'private - matching' }
KGCodeSearchTool >> matches: haystack query: query mode: mode [
	mode = 'substring' ifTrue: [ ^ haystack asLowercase includesSubstring: query asLowercase ].
	mode = 'exact' ifTrue: [ ^ haystack = query ].
	mode = 'regex' ifTrue: [ ^ haystack matchesRegex: query ].
	self error: 'match must be substring, exact, or regex'
]

{ #category : 'private - methods' }
KGCodeSearchTool >> method: method matchesProtocol: protocol [
	^ protocol isNil or: [ method protocolName asString = protocol ]
]

{ #category : 'private - methods' }
KGCodeSearchTool >> methodRecord: method classification: classification origin: origin includeSource: includeSource [
	| record |
	record := OrderedDictionary new
		at: 'kind' put: 'method';
		at: 'class' put: method methodClass instanceSide name asString;
		at: 'side' put: (method methodClass isMeta ifTrue: [ 'class' ] ifFalse: [ 'instance' ]);
		at: 'selector' put: method selector asString;
		at: 'protocol' put: method protocolName asString;
		at: 'package' put: method package name asString;
		at: 'origin' put: origin instanceSide name asString;
		at: 'originKind' put: (origin isTrait ifTrue: [ 'trait' ] ifFalse: [ 'class' ]);
		at: 'classification' put: classification;
		yourself.
	includeSource ifTrue: [ record at: 'source' put: method sourceCode ].
	^ record
]

{ #category : 'private - sorting' }
KGCodeSearchTool >> methodRecord: a precedes: b [
	^ (self sortKeyForMethodRecord: a) < (self sortKeyForMethodRecord: b)
]

{ #category : 'accessing' }
KGCodeSearchTool >> methodSource: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| classSide selector method scope record |
	classSide := self classSideFor: aRequest.
	selector := (aRequest at: 'selector') asSymbol.
	method := classSide compiledMethodAt: selector ifAbsent: [
		self error: 'method not found: ' , classSide name , '>>#' , selector ].
	scope := KGCodePackageScope forRequest: aRequest.
	record := self methodRecord: method classification: 'local' origin: classSide includeSource: true.
	record at: 'sha256' put: (SHA256 hashMessage: method sourceCode utf8Encoded) hex.
	record at: 'text' put: (record at: 'source').
	^ self exactResponse: record scope: scope
]

{ #category : 'navigation' }
KGCodeSearchTool >> navigationResponseFor: records request: aRequest [
	| scope limit sorted accounted |
	scope := KGCodePackageScope forRequest: aRequest.
	limit := aRequest at: 'limit' ifAbsent: [ 500 ].
	sorted := records sorted: [ :a :b | self methodRecord: a precedes: b ].
	accounted := scope account: sorted limit: limit.
	^ accounted
]

{ #category : 'accessing' }
KGCodeSearchTool >> packageInfo: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| package scope local extensionGroups allEdges record |
	package := RPackageOrganizer default
		packageNamed: (aRequest at: 'packageName')
		ifAbsent: [ self error: 'package not found: ' , (aRequest at: 'packageName') ].
	scope := KGCodePackageScope forRequest: aRequest.
	local := package methods reject: [ :method | method isExtension ].
	extensionGroups := OrderedCollection new.
	(package extensionMethods groupedBy: [ :method | method methodClass instanceSide name asString ]) associations
		do: [ :association |
			extensionGroups add: (OrderedDictionary new
				at: 'class' put: association key;
				at: 'methods' put: (((association value collect: [ :method |
					self methodRecord: method classification: 'extension' origin: method methodClass includeSource: false ])
					sorted: [ :a :b | self methodRecord: a precedes: b ]) asArray);
				yourself) ].
	allEdges := scope dependencyEdges.
	record := OrderedDictionary new
		at: 'package' put: package name asString;
		at: 'classes' put: ((package definedClasses reject: #isTrait thenCollect: [ :each | each name asString ]) asArray sorted);
		at: 'traits' put: ((package definedClasses select: #isTrait thenCollect: [ :each | each name asString ]) asArray sorted);
		at: 'localMethods' put: (((local collect: [ :method |
			self methodRecord: method classification: 'local' origin: method methodClass includeSource: false ])
			sorted: [ :a :b | self methodRecord: a precedes: b ]) asArray);
		at: 'extensionMethods' put: (extensionGroups sorted: [ :a :b | (a at: 'class') < (b at: 'class') ]) asArray;
		at: 'outgoingDependencies' put: (allEdges select: [ :edge | (edge at: 'source') = package name asString ]);
		at: 'incomingDependencies' put: (allEdges select: [ :edge | (edge at: 'target') = package name asString ]);
		yourself.
	^ self exactResponse: record scope: scope
]

{ #category : 'accessing' }
KGCodeSearchTool >> packageSets: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	^ (KGCodePackageScope forRequest: aRequest) packageSets
]

{ #category : 'navigation' }
KGCodeSearchTool >> pragmas: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| selector records |
	selector := (aRequest at: 'pragma') asSymbol.
	records := selector gtPragmas contents collect: [ :method |
		self methodRecord: method classification: 'local' origin: method methodClass includeSource: false ].
	^ self navigationResponseFor: records request: aRequest
]

{ #category : 'navigation' }
KGCodeSearchTool >> references: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| value kind methods records global |
	value := aRequest at: 'value'.
	kind := aRequest at: 'kind'.
	(#('class' 'global' 'symbol' 'string') includes: kind) ifFalse: [
		self error: 'reference kind must be class, global, symbol, or string' ].
	(kind = 'class' or: [ kind = 'global' ])
		ifTrue: [
			global := Smalltalk globals at: value asSymbol ifAbsent: [ self error: 'global not found: ' , value ].
			methods := global gtReferences contents ]
		ifFalse: [
			methods := self allMethods select: [ :method |
				method ast allChildren anySatisfy: [ :node |
					node isLiteralNode and: [
						kind = 'symbol'
							ifTrue: [ node value isSymbol and: [ node value asString = value ] ]
							ifFalse: [ node value isString and: [ node value = value ] ] ] ] ] ].
	records := methods collect: [ :method |
		self methodRecord: method classification: 'local' origin: method methodClass includeSource: false ].
	^ self navigationResponseFor: records request: aRequest
]

{ #category : 'searching' }
KGCodeSearchTool >> search: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| query kind searchIn match limit records scope response |
	query := aRequest at: 'query'.
	kind := aRequest at: 'kind' ifAbsent: [ 'all' ].
	searchIn := aRequest at: 'in' ifAbsent: [ 'auto' ].
	match := aRequest at: 'match' ifAbsent: [ 'substring' ].
	limit := aRequest at: 'limit' ifAbsent: [ 500 ].
	(#('all' 'class' 'method') includes: kind) ifFalse: [ self error: 'kind must be all, class, or method' ].
	(#('auto' 'class-name' 'selector' 'source') includes: searchIn) ifFalse: [ self error: 'in must be auto, class-name, selector, or source' ].
	records := OrderedCollection new.
	(kind = 'all' or: [ kind = 'class' ]) ifTrue: [
		(searchIn = 'auto' or: [ searchIn = 'class-name' ]) ifTrue: [
			self allClasses do: [ :aClass |
				(self matches: aClass name asString query: query mode: match) ifTrue: [
					records add: (OrderedDictionary new
						at: 'kind' put: 'class';
						at: 'class' put: aClass name asString;
						at: 'package' put: aClass package name asString;
						yourself) ] ] ] ].
	(kind = 'all' or: [ kind = 'method' ]) ifTrue: [
		self allMethods do: [ :method |
			| haystack |
			haystack := searchIn = 'class-name'
				ifTrue: [ method methodClass instanceSide name asString ]
				ifFalse: [ searchIn = 'selector'
					ifTrue: [ method selector asString ]
					ifFalse: [ searchIn = 'source'
						ifTrue: [ method sourceCode ]
						ifFalse: [ method methodClass instanceSide name asString , ' ' , method selector asString , ' ' , method sourceCode ] ] ].
			(self matches: haystack query: query mode: match) ifTrue: [
				records add: (self methodRecord: method classification: 'local' origin: method methodClass includeSource: false) ] ] ].
	records := records sorted: [ :a :b |
		(a at: 'kind') , String cr , (a at: 'class') , String cr , (a at: 'side' ifAbsent: [ '' ]) , String cr , (a at: 'selector' ifAbsent: [ '' ]) <
			((b at: 'kind') , String cr , (b at: 'class') , String cr , (b at: 'side' ifAbsent: [ '' ]) , String cr , (b at: 'selector' ifAbsent: [ '' ])) ].
	scope := KGCodePackageScope forRequest: aRequest.
	response := scope account: records limit: limit.
	response at: 'query' put: query.
	response at: 'kind' put: kind.
	response at: 'in' put: searchIn.
	response at: 'match' put: match.
	response at: 'count' put: ((response at: 'counts') at: 'displayed').
	^ response
]

{ #category : 'navigation' }
KGCodeSearchTool >> senders: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| selector candidates records |
	selector := (aRequest at: 'selector') asSymbol.
	candidates := SystemNavigation default allSendersOf: selector.
	candidates := candidates select: [ :method |
		method ast allChildren anySatisfy: [ :node |
			node isMessage and: [ node selector = selector ] ] ].
	records := candidates collect: [ :method |
		self methodRecord: method classification: 'local' origin: method methodClass includeSource: false ].
	^ self navigationResponseFor: records request: aRequest
]

{ #category : 'private - sorting' }
KGCodeSearchTool >> sortKeyForMethodRecord: aRecord [
	^ (aRecord at: 'class') , String cr , (aRecord at: 'side') , String cr ,
		(aRecord at: 'selector') , String cr , (aRecord at: 'package')
]
