Class {
	#name : 'KGMethodArgChecker',
	#superclass : 'Object',
	#instVars : [
		'classNames',
		'totalMethods',
		'methodsWithArgs',
		'methodsWithAnyTypedArg',
		'totalArgs',
		'matchedArgs',
		'examples'
	],
	#category : 'KlibGenGt-Examples',
	#package : 'KlibGenGt-Examples'
}

{ #category : 'examples' }
KGMethodArgChecker >> candidateTypeNameFor: argName [
	| re |
	re := '(an?)(.+)' asRegex.
	(re search: argName) ifTrue: [ | maybeClassName |
		maybeClassName := (re subexpression: 3).
		(classNames includes: maybeClassName asSymbol)
			ifTrue: [ ^maybeClassName ]
	].
	^ nil
]

{ #category : 'accessing' }
KGMethodArgChecker >> classNames [
	^ classNames
]

{ #category : 'accessing' }
KGMethodArgChecker >> classNames: anObject [
	classNames := anObject
]

{ #category : 'as yet unclassified' }
KGMethodArgChecker >> initialize [
	totalMethods := 0.
	methodsWithArgs := 0.
	methodsWithAnyTypedArg := 0.
	totalArgs := 0.
	matchedArgs := 0.
	examples := OrderedCollection new.
	self loadClassNames.
]

{ #category : 'examples' }
KGMethodArgChecker >> loadClassNames [
	classNames isNil ifTrue: [ 
		classNames := IdentitySet new.
		Smalltalk globals keysAndValuesDo: [ :name :value | 
			value isBehavior ifTrue: [ classNames add: name ] 
		] ].
	^ classNames
]

{ #category : 'examples' }
KGMethodArgChecker >> run [
	| argMatchPercent methodMatchPercent |
	(classNames asOrderedCollection first: 100)
		do: [ :className | 
			| class meta |
			class := Smalltalk globals at: className.
			meta := class class.
			class methodsDo: [ :method | self scanMethod: method of: class ].
			meta methodsDo: [ :method | self scanMethod: method of: meta ] ].

	argMatchPercent := totalArgs = 0
			ifTrue: [ 0 ]
			ifFalse: [ matchedArgs * 100.0 / totalArgs ].

	methodMatchPercent := methodsWithArgs = 0
			ifTrue: [ 0 ]
			ifFalse: [ methodsWithAnyTypedArg * 100.0 / methodsWithArgs ].

	^ {
		#totalMethods -> totalMethods.
		#methodsWithArguments -> methodsWithArgs.
		#methodsWithAnyMatchedArgument -> methodsWithAnyTypedArg.
		#totalArguments -> totalArgs.
		#matchedArguments -> matchedArgs.
		#argumentMatchPercent -> argMatchPercent.
		#methodWithArgumentMatchPercent -> methodMatchPercent.
		#examples -> examples
	} asDictionary
]

{ #category : 'examples' }
KGMethodArgChecker >> scanMethod: method of: classOrMetaclass [
	| args methodHasMatch |
	totalMethods := totalMethods + 1.
	args := method ast arguments collect: [ :argNode | argNode name ].
	^ args isEmpty
		ifFalse: [ methodsWithArgs := methodsWithArgs + 1.
			methodHasMatch := false.
			args
				do: [ :argName | 
					| typeName |
					totalArgs := totalArgs + 1.
					typeName := self candidateTypeNameFor: argName.
					typeName
						ifNotNil: [ matchedArgs := matchedArgs + 1.
							methodHasMatch := true.
							examples size < 50
								ifTrue: [ examples
										add: {classOrMetaclass name.
												method selector.
												argName.
												typeName} ] ] ].
			methodHasMatch
				ifTrue: [ methodsWithAnyTypedArg := methodsWithAnyTypedArg + 1 ] ]
]
