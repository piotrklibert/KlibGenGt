"
AST node for a Kotlin function declaration.

- Slots
  - receiver <#(String?)> accessing - Optional extension receiver type.
  - parameters <#(Array<KGKotlinParameter>)> accessing - Function parameters.
  - returnType <#String> accessing - Return type text, or an empty string when omitted.
- Public API
  - {{gtMethod:KGKotlinFunctionDeclaration class>>#name:receiver:modifiers:annotations:parameters:returnType:}} - Build a function declaration node.
  - {{gtMethod:KGKotlinFunctionDeclaration>>#receiver}} - Answer the optional extension receiver type.
  - {{gtMethod:KGKotlinFunctionDeclaration>>#receiver:}} - Replace the optional extension receiver type.
  - {{gtMethod:KGKotlinFunctionDeclaration>>#parameters}} - Answer function parameters.
  - {{gtMethod:KGKotlinFunctionDeclaration>>#parameters:}} - Replace function parameters.
  - {{gtMethod:KGKotlinFunctionDeclaration>>#returnType}} - Answer return type text.
  - {{gtMethod:KGKotlinFunctionDeclaration>>#returnType:}} - Replace return type text.
  - {{gtMethod:KGKotlinFunctionDeclaration>>#asFixtureDictionary}} - Convert the declaration to fixture JSON shape.
"
Class {
	#name : 'KGKotlinFunctionDeclaration',
	#superclass : 'KGKotlinDeclaration',
	#instVars : [
		'receiver',
		'parameters',
		'returnType'
	],
	#category : 'KlibGenGt-Kotlin-Model',
	#package : 'KlibGenGt-Kotlin'
}

{ #category : 'instance creation' }
KGKotlinFunctionDeclaration class >> name: nameString receiver: receiverStringOrNil modifiers: modifierCollection annotations: annotationCollection parameters: parameterCollection returnType: returnTypeString [
	<arg: #nameString type: #String>
	<arg: #receiverStringOrNil type: #(String?)>
	<arg: #modifierCollection type: #(Collection | Array)>
	<arg: #annotationCollection type: #(Collection | Array)>
	<arg: #parameterCollection type: #(Collection | Array)>
	<arg: #returnTypeString type: #String>
	<return: #KGKotlinFunctionDeclaration>
	^ self new
		name: nameString;
		receiver: receiverStringOrNil;
		modifiers: modifierCollection;
		annotations: annotationCollection;
		parameters: parameterCollection;
		returnType: returnTypeString;
		yourself
]

{ #category : 'converting' }
KGKotlinFunctionDeclaration >> asFixtureDictionary [
	<return: #Dictionary>
	^ Dictionary new
		at: 'declarationKind' put: 'function';
		at: 'name' put: self name;
		at: 'receiver' put: self receiver;
		at: 'modifiers' put: self modifiers;
		at: 'annotations' put: self annotations;
		at: 'parameters' put: (self parameters collect: [ :each | each asFixtureDictionary ]);
		at: 'returnType' put: self returnType;
		yourself
]

{ #category : 'accessing' }
KGKotlinFunctionDeclaration >> parameters [
	<return: #Array>
	^ parameters ifNil: [ #() ]
]

{ #category : 'accessing' }
KGKotlinFunctionDeclaration >> parameters: aCollection [
	<arg: #aCollection type: #(Collection | Array)>
	<return: #Array>
	parameters := aCollection asArray
]

{ #category : 'accessing' }
KGKotlinFunctionDeclaration >> receiver [
	<return: #(String?)>
	^ receiver
]

{ #category : 'accessing' }
KGKotlinFunctionDeclaration >> receiver: aStringOrNil [
	<arg: #aStringOrNil type: #(String?)>
	<return: #(String?)>
	receiver := aStringOrNil
]

{ #category : 'accessing' }
KGKotlinFunctionDeclaration >> returnType [
	<return: #String>
	^ returnType ifNil: [ '' ]
]

{ #category : 'accessing' }
KGKotlinFunctionDeclaration >> returnType: aString [
	<arg: #aString type: #String>
	<return: #String>
	returnType := aString
]
