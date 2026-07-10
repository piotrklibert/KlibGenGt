"
AST node for a Kotlin class, interface, or object declaration.

- Slots
  - kind <#String> accessing - One of `class`, `interface`, or `object`.
  - typeParameters <#String> accessing - Raw type-parameter text, including angle brackets when present.
  - parameters <#(Array<KGKotlinParameter>)> accessing - Primary-constructor parameters.
  - supertypes <#(Array<String>)> accessing - Supertype texts in source order.
  - declarations <#(Array<KGKotlinDeclaration>)> accessing - Nested type or function declarations.
- Public API
  - {{gtMethod:KGKotlinTypeDeclaration class>>#kind:name:modifiers:annotations:typeParameters:parameters:supertypes:declarations:}} - Build a type declaration node.
  - {{gtMethod:KGKotlinTypeDeclaration>>#kind}} - Answer the Kotlin type kind.
  - {{gtMethod:KGKotlinTypeDeclaration>>#kind:}} - Replace the Kotlin type kind.
  - {{gtMethod:KGKotlinTypeDeclaration>>#typeParameters}} - Answer raw type-parameter text.
  - {{gtMethod:KGKotlinTypeDeclaration>>#typeParameters:}} - Replace raw type-parameter text.
  - {{gtMethod:KGKotlinTypeDeclaration>>#parameters}} - Answer primary-constructor parameters.
  - {{gtMethod:KGKotlinTypeDeclaration>>#parameters:}} - Replace primary-constructor parameters.
  - {{gtMethod:KGKotlinTypeDeclaration>>#supertypes}} - Answer supertypes.
  - {{gtMethod:KGKotlinTypeDeclaration>>#supertypes:}} - Replace supertypes.
  - {{gtMethod:KGKotlinTypeDeclaration>>#declarations}} - Answer nested declarations.
  - {{gtMethod:KGKotlinTypeDeclaration>>#declarations:}} - Replace nested declarations.
  - {{gtMethod:KGKotlinTypeDeclaration>>#asFixtureDictionary}} - Convert the declaration to fixture JSON shape.
"
Class {
	#name : 'KGKotlinTypeDeclaration',
	#superclass : 'KGKotlinDeclaration',
	#instVars : [
		'kind',
		'typeParameters',
		'parameters',
		'supertypes',
		'declarations'
	],
	#category : 'KlibGenGt-Kotlin-Model',
	#package : 'KlibGenGt-Kotlin'
}

{ #category : 'instance creation' }
KGKotlinTypeDeclaration class >> kind: kindString name: nameString modifiers: modifierCollection annotations: annotationCollection typeParameters: typeParameterString parameters: parameterCollection supertypes: supertypeCollection declarations: declarationCollection [
	<arg: #kindString type: #String>
	<arg: #nameString type: #String>
	<arg: #modifierCollection type: #(Collection | Array)>
	<arg: #annotationCollection type: #(Collection | Array)>
	<arg: #typeParameterString type: #String>
	<arg: #parameterCollection type: #(Collection | Array)>
	<arg: #supertypeCollection type: #(Collection | Array)>
	<arg: #declarationCollection type: #(Collection | Array)>
	<return: #KGKotlinTypeDeclaration>
	^ self new
		kind: kindString;
		name: nameString;
		modifiers: modifierCollection;
		annotations: annotationCollection;
		typeParameters: typeParameterString;
		parameters: parameterCollection;
		supertypes: supertypeCollection;
		declarations: declarationCollection;
		yourself
]

{ #category : 'converting' }
KGKotlinTypeDeclaration >> asFixtureDictionary [
	<return: #Dictionary>
	^ Dictionary new
		at: 'declarationKind' put: 'type';
		at: 'kind' put: self kind;
		at: 'name' put: self name;
		at: 'modifiers' put: self modifiers;
		at: 'annotations' put: self annotations;
		at: 'typeParameters' put: self typeParameters;
		at: 'parameters' put: (self parameters collect: [ :each | each asFixtureDictionary ]);
		at: 'supertypes' put: self supertypes;
		at: 'declarations' put: (self declarations collect: [ :each | each asFixtureDictionary ]);
		yourself
]

{ #category : 'accessing' }
KGKotlinTypeDeclaration >> declarations [
	<return: #Array>
	^ declarations ifNil: [ #() ]
]

{ #category : 'accessing' }
KGKotlinTypeDeclaration >> declarations: aCollection [
	<arg: #aCollection type: #(Collection | Array)>
	<return: #Array>
	declarations := aCollection asArray
]

{ #category : 'accessing' }
KGKotlinTypeDeclaration >> kind [
	<return: #String>
	^ kind ifNil: [ '' ]
]

{ #category : 'accessing' }
KGKotlinTypeDeclaration >> kind: aString [
	<arg: #aString type: #String>
	<return: #String>
	kind := aString
]

{ #category : 'accessing' }
KGKotlinTypeDeclaration >> parameters [
	<return: #Array>
	^ parameters ifNil: [ #() ]
]

{ #category : 'accessing' }
KGKotlinTypeDeclaration >> parameters: aCollection [
	<arg: #aCollection type: #(Collection | Array)>
	<return: #Array>
	parameters := aCollection asArray
]

{ #category : 'accessing' }
KGKotlinTypeDeclaration >> supertypes [
	<return: #Array>
	^ supertypes ifNil: [ #() ]
]

{ #category : 'accessing' }
KGKotlinTypeDeclaration >> supertypes: aCollection [
	<arg: #aCollection type: #(Collection | Array)>
	<return: #Array>
	supertypes := aCollection asArray
]

{ #category : 'accessing' }
KGKotlinTypeDeclaration >> typeParameters [
	<return: #String>
	^ typeParameters ifNil: [ '' ]
]

{ #category : 'accessing' }
KGKotlinTypeDeclaration >> typeParameters: aString [
	<arg: #aString type: #String>
	<return: #String>
	typeParameters := aString
]
