"
Abstract base class for Kotlin declaration AST nodes.

- Slots
  - name <#String> accessing - Declaration name.
  - modifiers <#(Array<String>)> accessing - Kotlin modifiers in source order.
  - annotations <#(Array<String>)> accessing - Annotation summaries in source order.
- Public API
  - {{gtMethod:KGKotlinDeclaration>>#name}} - Answer the declaration name.
  - {{gtMethod:KGKotlinDeclaration>>#name:}} - Replace the declaration name.
  - {{gtMethod:KGKotlinDeclaration>>#modifiers}} - Answer declaration modifiers.
  - {{gtMethod:KGKotlinDeclaration>>#modifiers:}} - Replace declaration modifiers.
  - {{gtMethod:KGKotlinDeclaration>>#annotations}} - Answer declaration annotation summaries.
  - {{gtMethod:KGKotlinDeclaration>>#annotations:}} - Replace declaration annotation summaries.
  - {{gtMethod:KGKotlinDeclaration>>#asFixtureDictionary}} - Convert the declaration to fixture JSON shape.
"
Class {
	#name : 'KGKotlinDeclaration',
	#superclass : 'Object',
	#instVars : [
		'name',
		'modifiers',
		'annotations'
	],
	#category : 'KlibGenGt-Kotlin-Model',
	#package : 'KlibGenGt-Kotlin'
}

{ #category : 'accessing' }
KGKotlinDeclaration >> annotations [
	<return: #Array>
	^ annotations ifNil: [ #() ]
]

{ #category : 'accessing' }
KGKotlinDeclaration >> annotations: aCollection [
	<arg: #aCollection type: #(Collection | Array)>
	<return: #Array>
	annotations := aCollection asArray
]

{ #category : 'converting' }
KGKotlinDeclaration >> asFixtureDictionary [
	<return: #Dictionary>
	self subclassResponsibility
]

{ #category : 'accessing' }
KGKotlinDeclaration >> modifiers [
	<return: #Array>
	^ modifiers ifNil: [ #() ]
]

{ #category : 'accessing' }
KGKotlinDeclaration >> modifiers: aCollection [
	<arg: #aCollection type: #(Collection | Array)>
	<return: #Array>
	modifiers := aCollection asArray
]

{ #category : 'accessing' }
KGKotlinDeclaration >> name [
	<return: #String>
	^ name ifNil: [ '' ]
]

{ #category : 'accessing' }
KGKotlinDeclaration >> name: aString [
	<arg: #aString type: #String>
	<return: #String>
	name := aString
]
