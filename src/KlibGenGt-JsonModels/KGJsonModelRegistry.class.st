"Registry that dispatches named KlibGen JSON records to generated classes.

- Slots
  - `Registry` (`#(Dictionary<String, Class>)`, class state, `registration`) - Lazily rebuilt schema-to-class mapping.
- Public API
  - {{gtMethod:KGJsonModelRegistry class>>#parseDictionary:}}
    Parse a dictionary through its exact named schema.
  - {{gtMethod:KGJsonModelRegistry class>>#parseJson:}}
    Parse a JSON string through its exact named schema.
  - {{gtMethod:KGJsonModelRegistry class>>#reset}}
    Clear the lazy registry for isolated tests and package reloads.
"
Class {
	#name : 'KGJsonModelRegistry',
	#superclass : 'Object',
	#classVars : [
		'Registry'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'registration' }
KGJsonModelRegistry class >> rebuild [
	<return: #(Dictionary<String, Class>)>
	Registry := Dictionary new.
	KGJsonRecord allSubclasses do: [ :recordClass |
		| schema |
		schema := recordClass jsonSchemaName.
		schema ifNotNil: [
			(Registry includesKey: schema) ifTrue: [ self error: 'Duplicate JSON schema ', schema ].
			Registry at: schema put: recordClass ] ].
	^ Registry
]

{ #category : 'accessing' }
KGJsonModelRegistry class >> registry [
	<return: #(Dictionary<String, Class>)>
	^ Registry ifNil: [ self rebuild ]
]

{ #category : 'parsing' }
KGJsonModelRegistry class >> parseDictionary: aDictionary [
	<arg: #aDictionary type: #(Dictionary<String, Any>)>
	<return: #KGJsonRecord>
	| schema recordClass |
	schema := aDictionary at: 'schema' ifAbsent: [ self error: 'Named JSON record has no schema' ].
	recordClass := self registry at: schema ifAbsent: [ self error: 'Unknown named KlibGen JSON schema ', schema asString ].
	^ recordClass fromDictionary: aDictionary
]

{ #category : 'parsing' }
KGJsonModelRegistry class >> parseJson: aString [
	<arg: #aString type: #String>
	<return: #KGJsonRecord>
	^ self parseDictionary: (STONJSON fromString: aString)
]

{ #category : 'registration' }
KGJsonModelRegistry class >> reset [
	<return: #KGJsonModelRegistry>
	Registry := nil.
	^ self
]
