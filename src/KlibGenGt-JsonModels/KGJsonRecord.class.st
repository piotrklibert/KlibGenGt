"
Abstract runtime for immutable records generated from the host Pydantic catalog.

- Slots
  - `presentFields` (`#(Set<String>)`, `json`) - Wire fields present in the decoded record.
  - `extras` (`#(Dictionary<String, Any>)`, `json`) - Preserved extension fields for extensible schemas.
- Public API
  - {{gtMethod:KGJsonRecord class>>#fromDictionary:}}
    Validate and decode one JSON-compatible dictionary.
  - {{gtMethod:KGJsonRecord class>>#fromJson:}}
    Parse and validate one JSON string.
  - {{gtMethod:KGJsonRecord>>#asDictionary}}
    Encode the record with its original wire field names.
  - {{gtMethod:KGJsonRecord>>#asJson}}
    Encode the record as STON-JSON.
"
Class {
	#name : 'KGJsonRecord',
	#superclass : 'Object',
	#instVars : [
		'presentFields',
		'extras'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'private - decoding' }
KGJsonRecord class >> decodeJsonValue: aValue type: typeSpecification path: aPath [
	<arg: #aValue type: #Any>
	<arg: #typeSpecification type: #(Array<Any>)>
	<arg: #aPath type: #String>
	<return: #Any>
	| kind |
	kind := typeSpecification first.
	kind = #constrained ifTrue: [
		| decoded |
		decoded := self decodeJsonValue: aValue type: typeSpecification second path: aPath.
		typeSpecification third do: [ :constraint |
			constraint first = #ge ifTrue: [ decoded >= constraint second ifFalse: [ self error: aPath, ' is below its minimum' ] ].
			constraint first = #gt ifTrue: [ decoded > constraint second ifFalse: [ self error: aPath, ' must exceed its minimum' ] ].
			constraint first = #le ifTrue: [ decoded <= constraint second ifFalse: [ self error: aPath, ' exceeds its maximum' ] ].
			constraint first = #lt ifTrue: [ decoded < constraint second ifFalse: [ self error: aPath, ' must be below its maximum' ] ].
			constraint first = #minLength ifTrue: [ decoded size >= constraint second ifFalse: [ self error: aPath, ' is too short' ] ].
			constraint first = #maxLength ifTrue: [ decoded size <= constraint second ifFalse: [ self error: aPath, ' is too long' ] ].
			constraint first = #pattern ifTrue: [ (constraint second asRegex matches: decoded) ifFalse: [ self error: aPath, ' does not match its pattern' ] ] ].
		^ decoded ].
	kind = #any ifTrue: [ ^ self rawJsonCopy: aValue ].
	kind = #nil ifTrue: [ aValue isNil ifFalse: [ self error: aPath, ' must be nil' ]. ^ nil ].
	kind = #boolean ifTrue: [ ((aValue == true) or: [ aValue == false ]) ifFalse: [ self error: aPath, ' must be Boolean' ]. ^ aValue ].
	kind = #integer ifTrue: [ aValue isInteger ifFalse: [ self error: aPath, ' must be Integer' ]. ^ aValue ].
	kind = #number ifTrue: [ aValue isNumber ifFalse: [ self error: aPath, ' must be Number' ]. ^ aValue ].
	kind = #string ifTrue: [ aValue isString ifFalse: [ self error: aPath, ' must be String' ]. ^ aValue ].
	kind = #literal ifTrue: [ (typeSpecification second includes: aValue) ifFalse: [ self error: aPath, ' has an unsupported literal value' ]. ^ aValue ].
	kind = #model ifTrue: [
		aValue isDictionary ifFalse: [ self error: aPath, ' must be a JSON object' ].
		^ (Smalltalk globals at: typeSpecification second) fromDictionary: aValue ].
	kind = #array ifTrue: [
		((aValue isCollection and: [ aValue isString not ]) and: [ aValue isDictionary not ])
			ifFalse: [ self error: aPath, ' must be a JSON array' ].
		^ (aValue collect: [ :each | self decodeJsonValue: each type: typeSpecification second path: aPath ]) asArray ].
	kind = #dictionary ifTrue: [
		aValue isDictionary ifFalse: [ self error: aPath, ' must be a JSON object' ].
		^ aValue associations inject: OrderedDictionary new into: [ :result :association |
			association key isString ifFalse: [ self error: aPath, ' keys must be strings' ].
			result
				at: association key
				put: (self decodeJsonValue: association value type: typeSpecification second path: aPath, '.', association key);
				yourself ] ].
	kind = #union ifTrue: [
		| lastError |
		typeSpecification second do: [ :candidate |
			[ ^ self decodeJsonValue: aValue type: candidate path: aPath ]
				on: Error
				do: [ :error | lastError := error ] ].
		self error: aPath, ' does not match any allowed type: ', lastError messageText ].
	self error: 'Unsupported generated JSON type ', kind asString
]

{ #category : 'instance creation' }
KGJsonRecord class >> fromDictionary: aDictionary [
	<arg: #aDictionary type: #(Dictionary<String, Any>)>
	<return: #KGJsonRecord>
	^ self new initializeFromJsonDictionary: aDictionary
]

{ #category : 'instance creation' }
KGJsonRecord class >> fromJson: aString [
	<arg: #aString type: #String>
	<return: #KGJsonRecord>
	^ self fromDictionary: (STONJSON fromString: aString)
]

{ #category : 'json schema' }
KGJsonRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ #()
]

{ #category : 'json schema' }
KGJsonRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'private - copying' }
KGJsonRecord class >> rawJsonCopy: aValue [
	<arg: #aValue type: #Any>
	<return: #Any>
	aValue isDictionary ifTrue: [
		^ aValue associations inject: OrderedDictionary new into: [ :result :association |
			result at: association key put: (self rawJsonCopy: association value); yourself ] ].
	((aValue isCollection and: [ aValue isString not ]) and: [ aValue isDictionary not ])
		ifTrue: [ ^ (aValue collect: [ :each | self rawJsonCopy: each ]) asArray ].
	^ aValue
]

{ #category : 'encoding' }
KGJsonRecord >> asDictionary [
	<return: #(Dictionary<String, Any>)>
	| result |
	result := OrderedDictionary new.
	self class jsonFieldSpecifications do: [ :specification |
		(presentFields includes: specification first) ifTrue: [
			result
				at: specification first
				put: (self encodedJsonValue: (self instVarNamed: specification second)) ] ].
	extras keysAndValuesDo: [ :key :value | result at: key put: (self encodedJsonValue: value) ].
	^ result
]

{ #category : 'encoding' }
KGJsonRecord >> asJson [
	<return: #String>
	^ STONJSON toString: self asDictionary
]

{ #category : 'private - copying' }
KGJsonRecord >> defensiveJsonValue: aValue [
	<arg: #aValue type: #Any>
	<return: #Any>
	(aValue isKindOf: KGJsonRecord) ifTrue: [ ^ aValue ].
	^ self class rawJsonCopy: aValue
]

{ #category : 'private - encoding' }
KGJsonRecord >> encodedJsonValue: aValue [
	<arg: #aValue type: #Any>
	<return: #Any>
	(aValue isKindOf: KGJsonRecord) ifTrue: [ ^ aValue asDictionary ].
	aValue isDictionary ifTrue: [
		^ aValue associations inject: OrderedDictionary new into: [ :result :association |
			result at: association key put: (self encodedJsonValue: association value); yourself ] ].
	((aValue isCollection and: [ aValue isString not ]) and: [ aValue isDictionary not ])
		ifTrue: [ ^ (aValue collect: [ :each | self encodedJsonValue: each ]) asArray ].
	^ aValue
]

{ #category : 'initialization' }
KGJsonRecord >> initializeFromJsonDictionary: aDictionary [
	<arg: #aDictionary type: #(Dictionary<String, Any>)>
	<return: #KGJsonRecord>
	| knownFields |
	aDictionary isDictionary ifFalse: [ self error: 'JSON record must be a dictionary' ].
	presentFields := Set new.
	extras := OrderedDictionary new.
	knownFields := self class jsonFieldSpecifications collect: #first as: Set.
	self class jsonFieldSpecifications do: [ :specification |
		| wireName slotName value |
		wireName := specification first.
		slotName := specification second.
		(aDictionary includesKey: wireName)
			ifTrue: [
				presentFields add: wireName.
				value := self class
					decodeJsonValue: (aDictionary at: wireName)
					type: specification fourth
					path: wireName ]
			ifFalse: [
				specification third ifTrue: [ self error: 'Missing required JSON field ', wireName ].
				value := nil ].
		self instVarNamed: slotName put: value ].
	aDictionary keysAndValuesDo: [ :key :value |
		(knownFields includes: key) ifFalse: [
			self class jsonAllowsExtras
				ifTrue: [ extras at: key put: (self class rawJsonCopy: value) ]
				ifFalse: [ self error: 'Unknown JSON field ', key ] ] ].
	^ self
]
