"
Store immutable construction provenance embedded in a canonical project image.

- Slots
  - `Manifest` (`#(Dictionary<String, Any>?)`, `provenance`) - Resolved build manifest installed during canonical construction.
  - `ProjectKey` (`#(String?)`, `provenance`) - Expected canonical project artifact key.
- Public API
  - {{gtMethod:KGBuildProvenance class>>#installManifest:projectKey:}}
    Install immutable construction provenance before the image is published.
  - {{gtMethod:KGBuildProvenance class>>#manifest}}
    Answer a defensive copy of the installed build manifest.
  - {{gtMethod:KGBuildProvenance class>>#projectKey}}
    Answer the canonical project artifact key.
  - {{gtMethod:KGBuildProvenance class>>#verifyProjectKey:}}
    Require a launch-time project key to match the embedded provenance.
"
Class {
	#name : 'KGBuildProvenance',
	#superclass : 'Object',
	#classVars : [ 'Manifest', 'ProjectKey' ],
	#category : 'KlibGenGt-BuildSupport',
	#package : 'KlibGenGt-BuildSupport'
}

{ #category : 'installation' }
KGBuildProvenance class >> installManifest: aDictionary projectKey: aString [
	<arg: #aDictionary type: #(Dictionary<String, Any>)>
	<arg: #aString type: #String>
	<return: #KGBuildProvenance>
	Manifest := aDictionary copy.
	ProjectKey := aString copy.
	^ self
]

{ #category : 'accessing' }
KGBuildProvenance class >> manifest [
	<return: #(Dictionary<String, Any>)>
	Manifest ifNil: [ self error: 'Build provenance is not installed' ].
	^ Manifest copy
]

{ #category : 'accessing' }
KGBuildProvenance class >> projectKey [
	<return: #String>
	ProjectKey ifNil: [ self error: 'Build provenance is not installed' ].
	^ ProjectKey
]

{ #category : 'validation' }
KGBuildProvenance class >> verifyProjectKey: aString [
	<arg: #aString type: #String>
	<return: #Boolean>
	self projectKey = aString ifFalse: [
		self error: 'Project artifact key mismatch: expected ', self projectKey, ', got ', aString ].
	^ true
]
