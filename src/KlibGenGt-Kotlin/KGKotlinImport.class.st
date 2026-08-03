"
AST node for one Kotlin import directive.

- Slots
  - path <#String> accessing - Imported qualified path without alias text.
  - wildcard <#Boolean> accessing - Whether the import ends with `.*`.
  - alias <#(String?)> accessing - Optional `as` alias.
- Public API
  - {{gtMethod:KGKotlinImport class>>#path:wildcard:alias:}} - Build an import node.
  - {{gtMethod:KGKotlinImport>>#path}} - Answer the imported path.
  - {{gtMethod:KGKotlinImport>>#path:}} - Replace the imported path.
  - {{gtMethod:KGKotlinImport>>#wildcard}} - Answer whether this is a wildcard import.
  - {{gtMethod:KGKotlinImport>>#wildcard:}} - Replace the wildcard flag.
  - {{gtMethod:KGKotlinImport>>#alias}} - Answer the optional import alias.
  - {{gtMethod:KGKotlinImport>>#alias:}} - Replace the optional import alias.
  - {{gtMethod:KGKotlinImport>>#asFixtureDictionary}} - Convert the import to fixture JSON shape.
"
Class {
	#name : 'KGKotlinImport',
	#superclass : 'Object',
	#instVars : [
		'path',
		'wildcard',
		'alias'
	],
	#category : 'KlibGenGt-Kotlin-Model',
	#package : 'KlibGenGt-Kotlin',
	#tag : 'Model'
}

{ #category : 'instance creation' }
KGKotlinImport class >> path: pathString wildcard: wildcardBoolean alias: aliasStringOrNil [
	<arg: #pathString type: #String>
	<arg: #wildcardBoolean type: #Boolean>
	<arg: #aliasStringOrNil type: #(String?)>
	<return: #KGKotlinImport>
	^ self new
		path: pathString;
		wildcard: wildcardBoolean;
		alias: aliasStringOrNil;
		yourself
]

{ #category : 'accessing' }
KGKotlinImport >> alias [
	<return: #(String?)>
	^ alias
]

{ #category : 'accessing' }
KGKotlinImport >> alias: aStringOrNil [
	<arg: #aStringOrNil type: #(String?)>
	<return: #(String?)>
	alias := aStringOrNil
]

{ #category : 'converting' }
KGKotlinImport >> asFixtureDictionary [
	<return: #Dictionary>
	^ Dictionary new
		at: 'path' put: self path;
		at: 'wildcard' put: self wildcard;
		at: 'alias' put: self alias;
		yourself
]

{ #category : 'accessing' }
KGKotlinImport >> path [
	<return: #String>
	^ path ifNil: [ '' ]
]

{ #category : 'accessing' }
KGKotlinImport >> path: aString [
	<arg: #aString type: #String>
	<return: #String>
	path := aString
]

{ #category : 'accessing' }
KGKotlinImport >> wildcard [
	<return: #Boolean>
	^ wildcard ifNil: [ false ]
]

{ #category : 'accessing' }
KGKotlinImport >> wildcard: aBoolean [
	<arg: #aBoolean type: #Boolean>
	<return: #Boolean>
	wildcard := aBoolean
]
