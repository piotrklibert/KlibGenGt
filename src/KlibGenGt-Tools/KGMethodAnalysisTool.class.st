"
Build bounded source-accurate AST summaries and recursive static call graphs.

- Slots
  - scope: `KGCodePackageScope` in analysis; the request-local candidate universe.
  - request: `Dictionary<String, Any>` in analysis; analysis bounds and root identity.
  - codeTool: `KGCodeSearchTool` in analysis; normalized method-record facade.
  - nodes: `OrderedCollection<Dictionary<String, Any>>` in analysis; deduplicated analyzed methods.
  - edges: `OrderedCollection<Dictionary<String, Any>>` in analysis; send-to-candidate graph edges.
  - visited: `Set<String>` in analysis; normalized identities already expanded.
  - sourceCharacters: `Integer` in analysis; emitted-source budget usage.
  - truncations: `OrderedDictionary<String, Integer>` in analysis; bounded-output reasons.
  - excludedCandidates: `Integer` in analysis; package-suppressed callees across all sends.
- Public API
  - {{gtMethod:KGMethodAnalysisTool>>#analyze:}}
    Analyze one exact root and recursively expand bounded, package-filtered candidate callees.
"
Class {
	#name : 'KGMethodAnalysisTool',
	#superclass : 'Object',
	#instVars : [
		'scope',
		'request',
		'codeTool',
		'nodes',
		'edges',
		'visited',
		'sourceCharacters',
		'truncations',
		'excludedCandidates'
	],
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'private - analyzing' }
KGMethodAnalysisTool >> analysisFor: method includeSource: includeSource [
	| ast source variables sends literals globals pragmas arguments temporaries metrics record emittedSource references |
	ast := method ast.
	source := method sourceCode.
	variables := ast allChildren select: #isVariable.
	sends := ast allChildren select: #isMessage.
	literals := ast allChildren select: #isLiteralNode.
	globals := variables select: [ :node | node binding class name = #GlobalVariable ].
	pragmas := ast pragmas collect: [ :pragma |
		OrderedDictionary new
			at: 'selector' put: pragma selector asString;
			at: 'arguments' put: (pragma arguments collect: [ :argument | argument value printString ]) asArray;
			at: 'sourceInterval' put: { pragma start. pragma stop };
			yourself ].
	references := globals collect: [ :node |
		| value |
		value := Smalltalk globals at: node name ifAbsent: [ nil ].
		OrderedDictionary new
			at: 'name' put: node name asString;
			at: 'kind' put: ((value notNil and: [ value isBehavior ]) ifTrue: [ 'class' ] ifFalse: [ 'global' ]);
			at: 'sourceInterval' put: { node start. node stop };
			yourself ].
	arguments := (ast arguments collect: [ :node | node name asString ]) asArray.
	temporaries := (ast body temporaries collect: [ :node | node name asString ]) asArray.
	emittedSource := nil.
	includeSource ifTrue: [
		(sourceCharacters + source size <= (request at: 'maxSourceChars' ifAbsent: [ 1000000 ]))
			ifTrue: [ emittedSource := source. sourceCharacters := sourceCharacters + source size ]
			ifFalse: [ self noteTruncation: 'maxSourceChars' ] ].
	metrics := OrderedDictionary new
		at: 'lines' put: source lines size;
		at: 'astNodes' put: ast allChildren size + 1;
		at: 'sends' put: sends size;
		at: 'blocks' put: (ast allChildren count: #isBlock);
		at: 'returns' put: (ast allChildren count: #isReturn);
		yourself.
	record := OrderedDictionary new
		at: 'arguments' put: arguments;
		at: 'temporaries' put: temporaries;
		at: 'pragmas' put: pragmas asArray;
		at: 'literals' put: (((literals first: (100 min: literals size)) collect: [ :node |
			OrderedDictionary new
				at: 'value' put: node value printString;
				at: 'class' put: node value class name asString;
				at: 'sourceInterval' put: { node start. node stop };
				yourself ]) asArray);
		at: 'globals' put: ((globals collect: [ :node | node name asString ]) asSet asArray sorted);
		at: 'references' put: references asArray;
		at: 'variables' put: (variables collect: [ :node | self variableRecordFor: node ]) asArray;
		at: 'metrics' put: metrics;
		yourself.
	emittedSource ifNotNil: [ record at: 'source' put: emittedSource ].
	^ record
]

{ #category : 'analyzing' }
KGMethodAnalysisTool >> analyze: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| aClass side behavior selector root depth queue rootRecord |
	request := aRequest.
	scope := KGCodePackageScope forRequest: aRequest.
	codeTool := KGCodeSearchTool new.
	nodes := OrderedCollection new.
	edges := OrderedCollection new.
	visited := Set new.
	sourceCharacters := 0.
	truncations := OrderedDictionary new.
	excludedCandidates := 0.
	depth := aRequest at: 'depth' ifAbsent: [ 1 ].
	(depth between: 0 and: 5) ifFalse: [ self error: 'depth must be between 0 and 5' ].
	aClass := Smalltalk globals at: (aRequest at: 'class') asSymbol ifAbsent: [
		self error: 'class not found: ' , (aRequest at: 'class') ].
	side := aRequest at: 'side' ifAbsent: [ 'instance' ].
	(#('instance' 'class') includes: side) ifFalse: [ self error: 'side must be instance or class' ].
	behavior := side = 'class' ifTrue: [ aClass class ] ifFalse: [ aClass ].
	selector := (aRequest at: 'selector') asSymbol.
	root := behavior compiledMethodAt: selector ifAbsent: [
		self error: 'method not found: ' , behavior name , '>>#' , selector ].
	queue := OrderedCollection with: { root. 0 }.
	[ queue isNotEmpty ] whileTrue: [
		| entry method level identity |
		entry := queue removeFirst.
		method := entry first.
		level := entry second.
		identity := self identityOf: method.
		(visited includes: identity) ifFalse: [
			visited add: identity.
			visited size <= (aRequest at: 'maxMethods' ifAbsent: [ 100 ])
				ifTrue: [ self analyzeMethod: method level: level maxDepth: depth queue: queue ]
				ifFalse: [ self noteTruncation: 'maxMethods' ] ] ].
	rootRecord := nodes detect: [ :each | (each at: 'identity') = (self identityOf: root) ].
	"The JSON writer rejects shared collection identity. Keep the root report and
	the graph node independently serializable while retaining equal content."
	rootRecord := STONJSON fromString: (STONJSON toString: rootRecord).
	^ OrderedDictionary new
		at: 'scope' put: scope summary;
		at: 'rootOutsideScope' put: (scope includesPackageName: root package name asString) not;
		at: 'root' put: rootRecord;
		at: 'graph' put: (OrderedDictionary new
			at: 'nodes' put: (nodes sorted: [ :a :b | (a at: 'identity') < (b at: 'identity') ]) asArray;
			at: 'edges' put: (edges sorted: [ :a :b |
				(a at: 'from') , String cr , (a at: 'sendIndex') asString , String cr , (a at: 'to') <
					((b at: 'from') , String cr , (b at: 'sendIndex') asString , String cr , (b at: 'to')) ]) asArray;
			yourself);
		at: 'excludedCandidateCount' put: excludedCandidates;
		at: 'truncations' put: truncations;
		yourself
]

{ #category : 'private - analyzing' }
KGMethodAnalysisTool >> analyzeMethod: method level: level maxDepth: maxDepth queue: queue [
	| identity analysis sendNodes sendRecords nodeRecord includeSource |
	identity := self identityOf: method.
	includeSource := (request at: 'includeSource' ifAbsent: [ true ]).
	analysis := self analysisFor: method includeSource: includeSource.
	sendNodes := method ast allChildren select: #isMessage.
	sendRecords := OrderedCollection new.
	sendNodes withIndexDo: [ :send :index |
		| resolution candidates inScope capped excluded sendRecord |
		resolution := self candidatesFor: send inMethod: method.
		candidates := resolution at: 'methods'.
		inScope := candidates select: [ :candidate | scope includesPackageName: candidate package name asString ].
		excluded := candidates size - inScope size.
		excludedCandidates := excludedCandidates + excluded.
		capped := inScope first: ((request at: 'maxCandidates' ifAbsent: [ 20 ]) min: inScope size).
		inScope size > capped size ifTrue: [ self noteTruncation: 'maxCandidates' ].
		sendRecord := self sendRecordFor: send source: method sourceCode.
		sendRecord
			at: 'index' put: index;
			at: 'resolution' put: (resolution at: 'level');
			at: 'candidateCount' put: candidates size;
			at: 'excludedCandidateCount' put: excluded;
			at: 'candidates' put: (capped collect: [ :candidate | self identityOf: candidate ]) asArray.
		sendRecords add: sendRecord.
		capped do: [ :candidate |
			| candidateIdentity cycle |
			candidateIdentity := self identityOf: candidate.
			cycle := visited includes: candidateIdentity.
			edges add: (OrderedDictionary new
				at: 'from' put: identity;
				at: 'sendIndex' put: index;
				at: 'selector' put: send selector asString;
				at: 'to' put: candidateIdentity;
				at: 'resolution' put: (resolution at: 'level');
				at: 'cycle' put: cycle;
				yourself).
			(level < maxDepth and: [ cycle not ]) ifTrue: [ queue add: { candidate. level + 1 } ] ] ].
	analysis at: 'sends' put: sendRecords asArray.
	nodeRecord := codeTool methodRecord: method classification: 'local' origin: method methodClass includeSource: false.
	nodeRecord
		at: 'identity' put: identity;
		at: 'depth' put: level;
		at: 'analysis' put: analysis.
	nodes add: nodeRecord
]

{ #category : 'private - resolving' }
KGMethodAnalysisTool >> candidatesFor: send inMethod: method [
	| receiver selector target methods level global hierarchy |
	receiver := send receiver.
	selector := send selector.
	methods := OrderedCollection new.
	level := 'unresolved'.
	(receiver isVariable and: [ receiver name = #super ]) ifTrue: [
		target := method methodClass superclass.
		target ifNotNil: [
			(target lookupSelector: selector) ifNotNil: [ :candidate | methods add: candidate. level := 'exact' ] ].
		^ OrderedDictionary new at: 'methods' put: methods; at: 'level' put: level; yourself ].
	(receiver isVariable and: [ receiver name = #self ]) ifTrue: [
		hierarchy := { method methodClass } , method methodClass allSubclasses.
		hierarchy do: [ :behavior |
			(behavior lookupSelector: selector) ifNotNil: [ :candidate | methods add: candidate ] ].
		methods := methods asSet asOrderedCollection.
		methods isNotEmpty ifTrue: [ level := 'hierarchy' ].
		^ OrderedDictionary new at: 'methods' put: methods; at: 'level' put: level; yourself ].
	(receiver isVariable and: [ receiver binding class name = #GlobalVariable ]) ifTrue: [
		global := Smalltalk globals at: receiver name ifAbsent: [ nil ].
		(global notNil and: [ global isBehavior ]) ifTrue: [
			(global class lookupSelector: selector) ifNotNil: [ :candidate | methods add: candidate. level := 'exact' ].
			^ OrderedDictionary new at: 'methods' put: methods; at: 'level' put: level; yourself ] ].
	methods := SystemNavigation default allImplementorsOf: selector.
	methods isNotEmpty ifTrue: [ level := 'global' ].
	^ OrderedDictionary new at: 'methods' put: methods; at: 'level' put: level; yourself
]

{ #category : 'private - identities' }
KGMethodAnalysisTool >> identityOf: method [
	^ method methodClass instanceSide name asString ,
		(method methodClass isMeta ifTrue: [ ' class>>#' ] ifFalse: [ '>>#' ]) ,
		method selector asString
]

{ #category : 'private - truncation' }
KGMethodAnalysisTool >> noteTruncation: aReason [
	truncations at: aReason put: (truncations at: aReason ifAbsent: [ 0 ]) + 1
]

{ #category : 'private - analyzing' }
KGMethodAnalysisTool >> sendRecordFor: send source: source [
	| receiver receiverSource kind |
	receiver := send receiver.
	receiverSource := source copyFrom: receiver start to: receiver stop.
	kind := receiver isVariable
		ifTrue: [ (#(self super) includes: receiver name)
			ifTrue: [ receiver name asString ]
			ifFalse: [ receiver binding class name = #GlobalVariable
				ifTrue: [ 'literal-class-or-global' ]
				ifFalse: [ 'variable' ] ] ]
		ifFalse: [ receiver isLiteralNode ifTrue: [ 'literal' ] ifFalse: [ 'expression' ] ].
	^ OrderedDictionary new
		at: 'selector' put: send selector asString;
		at: 'receiverSource' put: receiverSource;
		at: 'receiverKind' put: kind;
		at: 'cascade' put: send isCascaded;
		at: 'sourceInterval' put: { send start. send stop };
		yourself
]

{ #category : 'private - analyzing' }
KGMethodAnalysisTool >> variableRecordFor: node [
	| role parent |
	parent := node parent.
	role := (parent isAssignment and: [ parent variable == node ])
		ifTrue: [ 'write' ]
		ifFalse: [ (parent isMethod or: [ parent isSequence or: [ parent isBlock ] ])
			ifTrue: [ 'definition' ]
			ifFalse: [ 'read' ] ].
	^ OrderedDictionary new
		at: 'name' put: node name asString;
		at: 'bindingKind' put: node binding class name asString;
		at: 'role' put: role;
		at: 'sourceInterval' put: { node start. node stop };
		yourself
]
