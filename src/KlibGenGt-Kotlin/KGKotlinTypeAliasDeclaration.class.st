"
AST node for a Kotlin type alias declaration.

- Slots
  - typeParameters <#String> accessing - Raw type-parameter text, including angle brackets when present.
  - targetType <#String> accessing - Aliased target type text.
- Public API
  - {{gtMethod:KGKotlinTypeAliasDeclaration class>>#name:modifiers:annotations:typeParameters:targetType:}} - Build a type alias declaration node.
  - {{gtMethod:KGKotlinTypeAliasDeclaration>>#typeParameters}} - Answer raw type-parameter text.
  - {{gtMethod:KGKotlinTypeAliasDeclaration>>#typeParameters:}} - Replace raw type-parameter text.
  - {{gtMethod:KGKotlinTypeAliasDeclaration>>#targetType}} - Answer aliased target type text.
  - {{gtMethod:KGKotlinTypeAliasDeclaration>>#targetType:}} - Replace aliased target type text.
  - {{gtMethod:KGKotlinTypeAliasDeclaration>>#asFixtureDictionary}} - Convert the declaration to fixture JSON shape.
"
Class {
	#name : 'KGKotlinTypeAliasDeclaration',
	#superclass : 'KGKotlinDeclaration',
	#instVars : [
		'typeParameters',
		'targetType'
	],
	#category : 'KlibGenGt-Kotlin-Model',
	#package : 'KlibGenGt-Kotlin'
}

{ #category : 'instance creation' }
KGKotlinTypeAliasDeclaration class >> name: nameString modifiers: modifierCollection annotations: annotationCollection typeParameters: typeParameterString targetType: targetTypeString [
	<arg: #nameString type: #String>
	<arg: #modifierCollection type: #(Collection | Array)>
	<arg: #annotationCollection type: #(Collection | Array)>
	<arg: #typeParameterString type: #String>
	<arg: #targetTypeString type: #String>
	<return: #KGKotlinTypeAliasDeclaration>
	^ self new
		name: nameString;
		modifiers: modifierCollection;
		annotations: annotationCollection;
		typeParameters: typeParameterString;
		targetType: targetTypeString;
		yourself
]

{ #category : 'converting' }
KGKotlinTypeAliasDeclaration >> asFixtureDictionary [
	<return: #Dictionary>
	^ Dictionary new
		at: 'declarationKind' put: 'typealias';
		at: 'name' put: self name;
		at: 'modifiers' put: self modifiers;
		at: 'annotations' put: self annotations;
		at: 'typeParameters' put: self typeParameters;
		at: 'targetType' put: self targetType;
		yourself
]

{ #category : 'accessing' }
KGKotlinTypeAliasDeclaration >> targetType [
	<return: #String>
	^ targetType ifNil: [ '' ]
]

{ #category : 'accessing' }
KGKotlinTypeAliasDeclaration >> targetType: aString [
	<arg: #aString type: #String>
	<return: #String>
	targetType := aString
]

{ #category : 'accessing' }
KGKotlinTypeAliasDeclaration >> typeParameters [
	<return: #String>
	^ typeParameters ifNil: [ '' ]
]

{ #category : 'accessing' }
KGKotlinTypeAliasDeclaration >> typeParameters: aString [
	<arg: #aString type: #String>
	<return: #String>
	typeParameters := aString
]
