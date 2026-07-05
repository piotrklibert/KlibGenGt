"
Example analysis that looks for argument names resembling class names.

- Slots
  - classNames <#(IdentitySet<Symbol>)> accessing - Class names considered valid type-name candidates.
  - totalMethods <#Integer> metrics - Count of scanned compiled methods.
  - methodsWithArgs <#Integer> metrics - Count of scanned methods that have arguments.
  - methodsWithAnyTypedArg <#Integer> metrics - Count of scanned methods with at least one matched argument name.
  - totalArgs <#Integer> metrics - Count of scanned argument names.
  - matchedArgs <#Integer> metrics - Count of argument names that matched a known class name.
  - examples <#(OrderedCollection<Array>)> metrics - Sample matches collected while scanning.
- Public API
  - {{gtMethod:KGMethodArgChecker>>#run}} - Scan a sample of loaded classes and answer summary metrics.
  - {{gtMethod:KGMethodArgChecker>>#loadClassNames}} - Initialize and answer known class names.
  - {{gtMethod:KGMethodArgChecker>>#classNames}} - Answer the configured class-name set.
  - {{gtMethod:KGMethodArgChecker>>#classNames:}} - Replace the configured class-name set.
  - {{gtMethod:KGMethodArgChecker>>#candidateTypeNameFor:}} - Infer a class-name candidate from an argument name.
  - {{gtMethod:KGMethodArgChecker>>#scanMethod:of:}} - Scan one compiled method into the accumulated metrics.
"
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
	<arg: #argName type: #String>
	<return: #(String?)>
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
	<return: #IdentitySet>
	^ classNames
]

{ #category : 'accessing' }
KGMethodArgChecker >> classNames: anObject [
	<arg: #anObject type: #(IdentitySet | Set)>
	<return: #(IdentitySet | Set)>
	classNames := anObject
]

{ #category : 'as yet unclassified' }
KGMethodArgChecker >> initialize [
	<return: #KGMethodArgChecker>
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
	<return: #IdentitySet>
	classNames isNil ifTrue: [ 
		classNames := IdentitySet new.
		Smalltalk globals keysAndValuesDo: [ :name :value | 
			value isBehavior ifTrue: [ classNames add: name ] 
		] ].
	^ classNames
]

{ #category : 'examples' }
KGMethodArgChecker >> run [
	<return: #Dictionary>
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
	<arg: #method type: #CompiledMethod>
	<arg: #classOrMetaclass type: #Behavior>
	<return: #(Boolean?)>
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
