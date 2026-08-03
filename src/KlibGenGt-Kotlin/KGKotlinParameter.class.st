"
AST node for a Kotlin function or primary-constructor parameter.

- Slots
  - name <#String> accessing - Parameter name.
  - type <#String> accessing - Parameter type text.
  - property <#(String?)> accessing - Optional constructor property marker, `val` or `var`.
- Public API
  - {{gtMethod:KGKotlinParameter class>>#name:type:property:}} - Build a parameter node.
  - {{gtMethod:KGKotlinParameter>>#name}} - Answer the parameter name.
  - {{gtMethod:KGKotlinParameter>>#name:}} - Replace the parameter name.
  - {{gtMethod:KGKotlinParameter>>#type}} - Answer the parameter type text.
  - {{gtMethod:KGKotlinParameter>>#type:}} - Replace the parameter type text.
  - {{gtMethod:KGKotlinParameter>>#property}} - Answer the optional constructor property marker.
  - {{gtMethod:KGKotlinParameter>>#property:}} - Replace the optional constructor property marker.
  - {{gtMethod:KGKotlinParameter>>#asFixtureDictionary}} - Convert the parameter to fixture JSON shape.
"
Class {
	#name : 'KGKotlinParameter',
	#superclass : 'Object',
	#instVars : [
		'name',
		'type',
		'property'
	],
	#category : 'KlibGenGt-Kotlin-Model',
	#package : 'KlibGenGt-Kotlin',
	#tag : 'Model'
}

{ #category : 'instance creation' }
KGKotlinParameter class >> name: nameString type: typeString property: propertyStringOrNil [
	<arg: #nameString type: #String>
	<arg: #typeString type: #String>
	<arg: #propertyStringOrNil type: #(String?)>
	<return: #KGKotlinParameter>
	^ self new
		name: nameString;
		type: typeString;
		property: propertyStringOrNil;
		yourself
]

{ #category : 'converting' }
KGKotlinParameter >> asFixtureDictionary [
	<return: #Dictionary>
	^ Dictionary new
		at: 'name' put: self name;
		at: 'type' put: self type;
		at: 'property' put: self property;
		yourself
]

{ #category : 'accessing' }
KGKotlinParameter >> name [
	<return: #String>
	^ name ifNil: [ '' ]
]

{ #category : 'accessing' }
KGKotlinParameter >> name: aString [
	<arg: #aString type: #String>
	<return: #String>
	name := aString
]

{ #category : 'accessing' }
KGKotlinParameter >> property [
	<return: #(String?)>
	^ property
]

{ #category : 'accessing' }
KGKotlinParameter >> property: aStringOrNil [
	<arg: #aStringOrNil type: #(String?)>
	<return: #(String?)>
	property := aStringOrNil
]

{ #category : 'accessing' }
KGKotlinParameter >> type [
	<return: #String>
	^ type ifNil: [ '' ]
]

{ #category : 'accessing' }
KGKotlinParameter >> type: aString [
	<arg: #aString type: #String>
	<return: #String>
	type := aString
]
