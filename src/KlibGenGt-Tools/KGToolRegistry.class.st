"
Own deterministic versioned lookup for every structured image tool.

- Slots
  - `registrations` (`#(Dictionary<String, KGToolRegistration>)`, `registry`) - Identifier-to-registration map.
  - `Default` (`#(KGToolRegistry?)`, class state, `registry`) - Lazily constructed standard registry.
- Public API
  - {{gtMethod:KGToolRegistry class>>#default}}
    Answer the complete standard registry.
  - {{gtMethod:KGToolRegistry class>>#resetDefault}}
    Clear class state for tests and image refresh.
  - {{gtMethod:KGToolRegistry>>#register:}}
    Register one unique identifier.
  - {{gtMethod:KGToolRegistry>>#at:}}
    Resolve an identifier or fail deterministically.
  - {{gtMethod:KGToolRegistry>>#identifiers}}
    Answer sorted registered identifiers.
"
Class {
	#name : 'KGToolRegistry',
	#superclass : 'Object',
	#instVars : [
		'registrations'
	],
	#classVars : [
		'Default'
	],
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'accessing' }
KGToolRegistry class >> default [
	<return: #KGToolRegistry>
	Default ifNil: [ Default := self new installStandardTools ]. ^ Default
]

{ #category : 'testing' }
KGToolRegistry class >> resetDefault [ <return: #KGToolRegistry> Default := nil. ^ self
]

{ #category : 'accessing' }
KGToolRegistry >> at: anIdentifier [
	<arg: #anIdentifier type: #String> <return: #KGToolRegistration>
	^ registrations at: anIdentifier ifAbsent: [ self error: 'unknown image tool operation: ', anIdentifier ]
]

{ #category : 'accessing' }
KGToolRegistry >> identifiers [ <return: #(Array<String>)> ^ registrations keys sorted asArray
]

{ #category : 'initialization' }
KGToolRegistry >> initialize [ <return: #KGToolRegistry> super initialize. registrations := Dictionary new. ^ self
]

{ #category : 'installation' }
KGToolRegistry >> installStandardTools [
	<return: #KGToolRegistry>
	self
		registerIdentifier: 'code.search' handler: [ :request | KGCodeSearchTool new search: request ];
		registerIdentifier: 'code.class' handler: [ :request | KGCodeSearchTool new classDefinition: request ];
		registerIdentifier: 'code.method' handler: [ :request | KGCodeSearchTool new methodSource: request ];
		registerIdentifier: 'code.class-methods' handler: [ :request | KGCodeSearchTool new classMethods: request ];
		registerIdentifier: 'code.class-info' handler: [ :request | KGCodeSearchTool new classInfo: request ];
		registerIdentifier: 'code.package-info' handler: [ :request | KGCodeSearchTool new packageInfo: request ];
		registerIdentifier: 'code.package-sets' handler: [ :request | KGCodeSearchTool new packageSets: request ];
		registerIdentifier: 'code.analyze' handler: [ :request | KGMethodAnalysisTool new analyze: request ];
		registerIdentifier: 'code.implementors' handler: [ :request | KGCodeSearchTool new implementors: request ];
		registerIdentifier: 'code.senders' handler: [ :request | KGCodeSearchTool new senders: request ];
		registerIdentifier: 'code.references' handler: [ :request | KGCodeSearchTool new references: request ];
		registerIdentifier: 'code.pragmas' handler: [ :request | KGCodeSearchTool new pragmas: request ];
		registerIdentifier: 'lepiter.search' handler: [ :request | KGLepiterTool new search: request ];
		registerIdentifier: 'lepiter.export' handler: [ :request | KGLepiterTool new export: request ];
		registerIdentifier: 'eval' handler: [ :request | KGEvaluationTool new evaluate: request ];
		registerIdentifier: 'test.all' handler: [ :request | KGTestTool new runAllProjectTests ];
		registerIdentifier: 'test.run' handler: [ :request | KGTestTool new run: request ];
		registerIdentifier: 'build-map.png' handler: [ :request | KGBuildMapTool new exportPngs: request ].
	self
		register: (KGToolRegistration identifier: 'refactor.catalog' version: 1 frontends: #('headless' 'gui') capabilities: #() handler: [ :request | KGRefactoringTool new catalog: request ]);
		register: (KGToolRegistration identifier: 'refactor.describe' version: 1 frontends: #('headless' 'gui') capabilities: #() handler: [ :request | KGRefactoringTool new describe: request ]);
		register: (KGToolRegistration identifier: 'refactor.applicable' version: 1 frontends: #('headless') capabilities: #('staged-source') handler: [ :request | KGRefactoringTool new applicable: request ]);
		register: (KGToolRegistration identifier: 'refactor.preview' version: 1 frontends: #('headless') capabilities: #('staged-source') handler: [ :request | KGRefactoringTool new preview: request ]);
		register: (KGToolRegistration identifier: 'refactor.apply' version: 1 frontends: #('headless') capabilities: #('staged-source') handler: [ :request | KGRefactoringTool new apply: request ]).
	^ self
]

{ #category : 'registration' }
KGToolRegistry >> register: aRegistration [
	<arg: #aRegistration type: #KGToolRegistration> <return: #KGToolRegistry>
	(registrations includesKey: aRegistration identifier) ifTrue: [ self error: 'duplicate image tool registration: ', aRegistration identifier ].
	registrations at: aRegistration identifier put: aRegistration. ^ self
]

{ #category : 'registration' }
KGToolRegistry >> registerIdentifier: anIdentifier handler: aBlock [
	<arg: #anIdentifier type: #String> <arg: #aBlock type: #((Dictionary<String, Any>) -> (Dictionary<String, Any>))> <return: #KGToolRegistry>
	^ self register: (KGToolRegistration identifier: anIdentifier version: 1 frontends: #('headless' 'gui') capabilities: #() handler: aBlock)
]
