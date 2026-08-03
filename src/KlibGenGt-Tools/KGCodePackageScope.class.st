"
Resolve a named universe of loaded packages for one structured code-tool request.

- Slots
  - request: `Dictionary<String, Any>` in accessing; the request whose scope is resolved.
  - setName: `String` in accessing; the selected named package set.
  - description: `String` in accessing; the human-readable set rule.
  - packages: `Set<Package>` in accessing; the effective loaded packages.
  - inclusions: `Array<String>` in accessing; normalized explicit inclusions.
  - exclusions: `Array<String>` in accessing; normalized explicit exclusions.
  - distances: `Dictionary<String, Integer>` in accessing; dependency distance where meaningful.
  - edges: `Array<Dictionary<String, String>>` in accessing; dependency edges observed while resolving.
- Public API
  - {{gtMethod:KGCodePackageScope class>>#forRequest:}}
    Build and validate a request-local package scope.
  - {{gtMethod:KGCodePackageScope>>#includesPackageName:}}
    Test whether an exact loaded package name belongs to the effective scope.
  - {{gtMethod:KGCodePackageScope>>#summary}}
    Return the JSON-compatible scope description included in command responses.
  - {{gtMethod:KGCodePackageScope>>#account:limit:}}
    Count all matches before scope filtering and limiting, then return displayed records and suppression metadata.
  - {{gtMethod:KGCodePackageScope>>#packageSets}}
    Describe and resolve every named package set, or the requested one.
  - {{gtMethod:KGCodePackageScope>>#dependencyEdges}}
    Return the request-local loaded-package dependency graph.
"
Class {
	#name : 'KGCodePackageScope',
	#superclass : 'Object',
	#instVars : [
		'request',
		'setName',
		'description',
		'packages',
		'inclusions',
		'exclusions',
		'distances',
		'edges'
	],
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'instance creation' }
KGCodePackageScope class >> forRequest: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #KGCodePackageScope>
	^ self new initializeForRequest: aRequest
]

{ #category : 'accounting' }
KGCodePackageScope >> account: allRecords limit: aLimit [
	<arg: #allRecords type: #(Collection<(Dictionary<String, Any>)>)>
	<arg: #aLimit type: #Integer>
	<return: #(Dictionary<String, Any>)>
	| inScope outScope displayed kinds perKind breakdown groups sortedGroups |
	aLimit < 0 ifTrue: [ self error: 'limit must be non-negative' ].
	inScope := allRecords select: [ :each |
		self includesPackageName: (each at: 'package') ].
	outScope := allRecords reject: [ :each |
		self includesPackageName: (each at: 'package') ].
	displayed := inScope first: (aLimit min: inScope size).
	kinds := OrderedDictionary new.
	allRecords do: [ :each |
		| kind |
		kind := each at: 'kind' ifAbsent: [ 'method' ].
		kinds at: kind put: (kinds at: kind ifAbsent: [ 0 ]) + 1 ].
	perKind := OrderedDictionary new.
	kinds keys sorted do: [ :kind |
		perKind at: kind put: (OrderedDictionary new
			at: 'total' put: (allRecords count: [ :each | (each at: 'kind' ifAbsent: [ 'method' ]) = kind ]);
			at: 'inScope' put: (inScope count: [ :each | (each at: 'kind' ifAbsent: [ 'method' ]) = kind ]);
			at: 'outOfScope' put: (outScope count: [ :each | (each at: 'kind' ifAbsent: [ 'method' ]) = kind ]);
			at: 'displayed' put: (displayed count: [ :each | (each at: 'kind' ifAbsent: [ 'method' ]) = kind ]);
			yourself) ].
	breakdown := OrderedCollection new.
	groups := outScope groupedBy: [ :each | each at: 'package' ].
	sortedGroups := groups associations
		sorted: [ :a :b |
			a value size = b value size
				ifTrue: [ a key < b key ]
				ifFalse: [ a value size > b value size ] ].
	(sortedGroups first: (50 min: groups size)) do: [ :association |
			breakdown add: (OrderedDictionary new
				at: 'package' put: association key;
				at: 'count' put: association value size;
				yourself) ].
	^ OrderedDictionary new
		at: 'scope' put: self summary;
		at: 'counts' put: (OrderedDictionary new
			at: 'total' put: allRecords size;
			at: 'inScope' put: inScope size;
			at: 'outOfScope' put: outScope size;
			at: 'displayed' put: displayed size;
			at: 'inScopeTruncated' put: (inScope size - displayed size);
			at: 'byKind' put: kinds;
			at: 'perKind' put: perKind;
			at: 'outOfScopeByPackage' put: breakdown asArray;
			yourself);
		at: 'results' put: displayed asArray;
		yourself
]

{ #category : 'private - dependencies' }
KGCodePackageScope >> addEdgesFrom: aPackage to: targetPackages kind: kindName into: aCollection [
	| sourceName |
	sourceName := aPackage name asString.
	targetPackages do: [ :target |
		target = aPackage ifFalse: [
			aCollection add: (OrderedDictionary new
				at: 'source' put: sourceName;
				at: 'target' put: target name asString;
				at: 'kind' put: kindName;
				yourself) ] ]
]

{ #category : 'private - resolving' }
KGCodePackageScope >> allLoadedPackages [
	^ RPackageOrganizer default packages
		sorted: [ :a :b | a name asString < b name asString ]
]

{ #category : 'private - resolving' }
KGCodePackageScope >> closureFrom: rootPackages [
	| result frontier distance |
	result := rootPackages asSet.
	frontier := rootPackages asOrderedCollection.
	distance := 0.
	rootPackages do: [ :each | distances at: each name asString put: 0 ].
	[ frontier isNotEmpty ] whileTrue: [
		| next |
		next := OrderedCollection new.
		frontier do: [ :each |
			(self dependenciesOf: each) do: [ :dependency |
				(result includes: dependency) ifFalse: [
					result add: dependency.
					distances at: dependency name asString put: distance + 1.
					next add: dependency ] ] ].
		frontier := next.
		distance := distance + 1 ].
	^ result
]

{ #category : 'private - dependencies' }
KGCodePackageScope >> dependenciesOf: aPackage [
	^ aPackage gtPackagesUsed asSet
]

{ #category : 'accessing' }
KGCodePackageScope >> dependencyEdges [
	<return: #(Array<(Dictionary<String, String>)>)>
	edges ifNil: [
		| result |
		result := Set new.
		self allLoadedPackages do: [ :aPackage |
			| inheritance traits references extensions classified remainder |
			inheritance := aPackage gtPackagesUsedThroughSubclassing asSet.
			traits := aPackage gtPackagesUsedThroughTraitUsages asSet.
			references := aPackage gtPackagesUsedThroughClassReferences asSet.
			extensions := aPackage gtPackagesUsedThroughClassExtensions asSet.
			classified := inheritance , traits , references , extensions.
			remainder := aPackage gtPackagesUsed asSet difference: classified.
			self addEdgesFrom: aPackage to: inheritance kind: 'inheritance' into: result.
			self addEdgesFrom: aPackage to: traits kind: 'trait-use' into: result.
			self addEdgesFrom: aPackage to: references kind: 'class-reference' into: result.
			self addEdgesFrom: aPackage to: extensions kind: 'class-extension' into: result.
			self addEdgesFrom: aPackage to: remainder kind: 'extension-method-reference' into: result ].
		edges := result asArray sorted: [ :a :b |
			(a at: 'source') , String cr , (a at: 'target') , String cr , (a at: 'kind') <
				((b at: 'source') , String cr , (b at: 'target') , String cr , (b at: 'kind')) ] ].
	^ edges
]

{ #category : 'private - resolving' }
KGCodePackageScope >> descriptionFor: aSetName [
	^ OrderedDictionary new
		at: 'default' put: 'Alias of direct.';
		at: 'project' put: 'BaselineOfKlibGenGt and every KlibGenGt-* package.';
		at: 'direct' put: 'Project packages plus one outgoing package-dependency edge.';
		at: 'transitive' put: 'Complete outgoing dependency closure of project packages.';
		at: 'gt-framework' put: 'Loaded GT, Bloc, Brick, Lepiter, Roassal, Sparta, and Phlow package families.';
		at: 'pharo-core' put: 'Dependency closure of the configured loaded Pharo core anchors.';
		at: 'tests' put: 'Packages defining TestCase subclasses or having Test in their name.';
		at: 'all' put: 'Every package registered in the loaded image.';
		at: aSetName ifAbsent: [ self error: 'unknown package set: ' , aSetName ]
]

{ #category : 'private - resolving' }
KGCodePackageScope >> familyPackageSet [
	| prefixes |
	prefixes := #('GToolkit' 'Gt' 'GT' 'Bloc' 'BlocPac' 'Brick' 'Lepiter' 'Roassal' 'Sparta' 'Phlow').
	^ self allLoadedPackages select: [ :each |
		prefixes anySatisfy: [ :prefix |
			each name asString beginsWith: prefix ] ]
]

{ #category : 'testing' }
KGCodePackageScope >> includesPackageName: aString [
	<arg: #aString type: #String>
	<return: #Boolean>
	^ packages anySatisfy: [ :each | each name asString = aString ]
]

{ #category : 'private - resolving' }
KGCodePackageScope >> initializeForRequest: aRequest [
	request := aRequest.
	distances := OrderedDictionary new.
	inclusions := self normalizedNamesAt: 'includePackages'.
	exclusions := self normalizedNamesAt: 'excludePackages'.
	(aRequest includesKey: 'package') ifTrue: [
		((aRequest includesKey: 'packageSet') or: [ inclusions isNotEmpty or: [ exclusions isNotEmpty ] ])
			ifTrue: [ self error: '--package cannot be combined with package-set overrides' ].
		setName := 'exact:' , (aRequest at: 'package').
		description := 'Deprecated exact-single-package scope.'.
		inclusions := { aRequest at: 'package' }.
		packages := Set new ] ifFalse: [
		setName := aRequest at: 'packageSet' ifAbsent: [ 'default' ].
		description := self descriptionFor: setName.
		packages := self resolveSetNamed: setName ].
	self validateNames: inclusions , exclusions.
	inclusions do: [ :name | packages add: (RPackageOrganizer default packageNamed: name) ].
	exclusions do: [ :name | packages remove: (RPackageOrganizer default packageNamed: name) ifAbsent: [ ] ]
]

{ #category : 'private - resolving' }
KGCodePackageScope >> normalizedNamesAt: aKey [
	| raw pieces |
	raw := request at: aKey ifAbsent: [ #() ].
	(raw isString or: [ raw isSymbol ]) ifTrue: [ raw := { raw } ].
	pieces := raw flatCollect: [ :each | each asString splitOn: $, ].
	^ ((pieces collect: #trimBoth thenReject: #isEmpty) asSet asArray sorted)
]

{ #category : 'accessing' }
KGCodePackageScope >> packageSets [
	<return: #(Dictionary<String, Any>)>
	| requested names records |
	requested := request at: 'set' ifAbsent: [ nil ].
	names := requested
		ifNil: [ #('default' 'project' 'direct' 'transitive' 'gt-framework' 'pharo-core' 'tests' 'all') ]
		ifNotNil: [ { requested } ].
	records := names collect: [ :name |
		| resolved localDistances record |
		localDistances := distances.
		distances := OrderedDictionary new.
		resolved := self resolveSetNamed: name.
		record := OrderedDictionary new
			at: 'name' put: name;
			at: 'description' put: (self descriptionFor: name);
			at: 'packages' put: ((resolved collect: [ :each | each name asString ]) asArray sorted);
			at: 'count' put: resolved size;
			at: 'distances' put: distances;
			yourself.
		distances := localDistances.
		record ].
	^ OrderedDictionary new
		at: 'sets' put: records;
		at: 'count' put: records size;
		yourself
]

{ #category : 'private - resolving' }
KGCodePackageScope >> pharoCoreAnchors [
	| names |
	names := #('Kernel' 'Collections-Abstract' 'Collections-Sequenceable' 'Collections-Streams'
		'Collections-Strings' 'Collections-Unordered' 'System-Support' 'System-Announcements'
		'System-SessionManager' 'System-Time' 'FileSystem-Core' 'OpalCompiler-Core' 'AST-Core'
		'Traits' 'Announcements-Core' 'SUnit-Core' 'STON-Core').
	^ names collect: [ :name |
		RPackageOrganizer default packageNamed: name ifAbsent: [ self error: 'core anchor package not loaded: ' , name ] ]
]

{ #category : 'private - resolving' }
KGCodePackageScope >> projectPackageSet [
	^ self allLoadedPackages select: [ :each |
		each name asString = 'BaselineOfKlibGenGt'
			or: [ each name asString beginsWith: 'KlibGenGt-' ] ]
]

{ #category : 'private - resolving' }
KGCodePackageScope >> resolveSetNamed: aSetName [
	| roots result |
	aSetName = 'all' ifTrue: [ ^ self allLoadedPackages asSet ].
	aSetName = 'project' ifTrue: [ ^ self projectPackageSet asSet ].
	(aSetName = 'default' or: [ aSetName = 'direct' ]) ifTrue: [
		roots := self projectPackageSet.
		roots do: [ :each | distances at: each name asString put: 0 ].
		result := roots asSet.
		roots do: [ :each |
			(self dependenciesOf: each) do: [ :dependency |
				result add: dependency.
				distances at: dependency name asString ifAbsentPut: [ 1 ] ] ].
		^ result ].
	aSetName = 'transitive' ifTrue: [ ^ self closureFrom: self projectPackageSet ].
	aSetName = 'gt-framework' ifTrue: [ ^ self familyPackageSet asSet ].
	aSetName = 'pharo-core' ifTrue: [ ^ self closureFrom: self pharoCoreAnchors ].
	aSetName = 'tests' ifTrue: [
		^ (self allLoadedPackages select: [ :each |
			(each name asString includesSubstring: 'Test') or: [
				each definedClasses anySatisfy: [ :aClass |
					aClass ~~ TestCase and: [ aClass inheritsFrom: TestCase ] ] ] ]) asSet ].
	self descriptionFor: aSetName.
	^ Set new
]

{ #category : 'accessing' }
KGCodePackageScope >> summary [
	<return: #(Dictionary<String, Any>)>
	| names fingerprint |
	names := (packages collect: [ :each | each name asString ]) asArray sorted.
	fingerprint := (SHA256 hashMessage: (String streamContents: [ :stream |
		names do: [ :name | stream nextPutAll: name; lf ] ])) hex.
	^ OrderedDictionary new
		at: 'set' put: setName;
		at: 'description' put: description;
		at: 'inclusions' put: inclusions;
		at: 'exclusions' put: exclusions;
		at: 'effectivePackageCount' put: names size;
		at: 'packages' put: names;
		at: 'fingerprint' put: fingerprint;
		at: 'distances' put: distances;
		yourself
]

{ #category : 'private - resolving' }
KGCodePackageScope >> validateNames: names [
	| loaded unknown |
	loaded := (self allLoadedPackages collect: [ :each | each name asString ]) asSet.
	unknown := names reject: [ :name | loaded includes: name ].
	unknown isNotEmpty ifTrue: [
		self error: 'unknown package name(s): ' , (', ' join: unknown sorted) ]
]
