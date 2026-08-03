"
Root AST node for one parsed Kotlin source file.

- Slots
  - packageName <#String> accessing - Kotlin package declaration, or an empty string when absent.
  - imports <#(Array<KGKotlinImport>)> accessing - Imports in source order.
  - declarations <#(Array<KGKotlinDeclaration>)> accessing - Top-level declarations in source order.
- Public API
  - {{gtMethod:KGKotlinFile class>>#packageName:imports:declarations:}} - Build a parsed file node.
  - {{gtMethod:KGKotlinFile>>#packageName}} - Answer the Kotlin package name.
  - {{gtMethod:KGKotlinFile>>#packageName:}} - Replace the Kotlin package name.
  - {{gtMethod:KGKotlinFile>>#imports}} - Answer imports in source order.
  - {{gtMethod:KGKotlinFile>>#imports:}} - Replace imports.
  - {{gtMethod:KGKotlinFile>>#declarations}} - Answer top-level declarations.
  - {{gtMethod:KGKotlinFile>>#declarations:}} - Replace top-level declarations.
  - {{gtMethod:KGKotlinFile>>#asFixtureDictionary}} - Convert the AST to the deterministic JSON fixture shape.
"
Class {
	#name : 'KGKotlinFile',
	#superclass : 'Object',
	#instVars : [
		'packageName',
		'imports',
		'declarations'
	],
	#category : 'KlibGenGt-Kotlin-Model',
	#package : 'KlibGenGt-Kotlin',
	#tag : 'Model'
}

{ #category : 'instance creation' }
KGKotlinFile class >> packageName: packageString imports: importCollection declarations: declarationCollection [
	<arg: #packageString type: #String>
	<arg: #importCollection type: #(Collection | Array)>
	<arg: #declarationCollection type: #(Collection | Array)>
	<return: #KGKotlinFile>
	^ self new
		packageName: packageString;
		imports: importCollection;
		declarations: declarationCollection;
		yourself
]

{ #category : 'converting' }
KGKotlinFile >> asFixtureDictionary [
	<return: #Dictionary>
	^ Dictionary new
		at: 'package' put: self packageName;
		at: 'imports' put: (self imports collect: [ :each | each asFixtureDictionary ]);
		at: 'declarations' put: (self declarations collect: [ :each | each asFixtureDictionary ]);
		yourself
]

{ #category : 'accessing' }
KGKotlinFile >> declarations [
	<return: #Array>
	^ declarations ifNil: [ #() ]
]

{ #category : 'accessing' }
KGKotlinFile >> declarations: aCollection [
	<arg: #aCollection type: #(Collection | Array)>
	<return: #Array>
	declarations := aCollection asArray
]

{ #category : 'accessing' }
KGKotlinFile >> imports [
	<return: #Array>
	^ imports ifNil: [ #() ]
]

{ #category : 'accessing' }
KGKotlinFile >> imports: aCollection [
	<arg: #aCollection type: #(Collection | Array)>
	<return: #Array>
	imports := aCollection asArray
]

{ #category : 'accessing' }
KGKotlinFile >> packageName [
	<return: #String>
	^ packageName ifNil: [ '' ]
]

{ #category : 'accessing' }
KGKotlinFile >> packageName: aString [
	<arg: #aString type: #String>
	<return: #String>
	packageName := aString
]
