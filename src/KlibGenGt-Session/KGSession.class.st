"
Represent immutable launch-time state and installed capabilities for one process.

- Slots
  - `manifest` (`#(Dictionary<String, Any>)`, `provenance`) - Validated `klibgen.session/1` manifest.
  - `sourceChanges` (`#Any`, `capabilities`) - Sole source mutation capability.
  - `persistence` (`#Any`, `capabilities`) - Sole image persistence capability.
  - `Current` (`#(KGSession?)`, class state, `installation`) - Process-global installed session.
- Public API
  - {{gtMethod:KGSession class>>#installManifest:sourceChanges:persistence:}}
    Install exactly one immutable session for the current process.
  - {{gtMethod:KGSession class>>#current}}
    Answer the installed session or fail when bootstrap has not run.
  - {{gtMethod:KGSession class>>#reset}}
    Clear process-global state for isolated tests.
  - {{gtMethod:KGSession>>#id}}
    Answer the session identifier.
  - {{gtMethod:KGSession>>#manifest}}
    Answer a defensive manifest copy.
  - {{gtMethod:KGSession>>#sourceChanges}}
    Answer the installed source capability.
  - {{gtMethod:KGSession>>#persistence}}
    Answer the installed persistence capability.
"
Class {
	#name : 'KGSession',
	#superclass : 'Object',
	#instVars : [ 'manifest', 'sourceChanges', 'persistence' ],
	#classVars : [ 'Current' ],
	#category : 'KlibGenGt-Session',
	#package : 'KlibGenGt-Session'
}

{ #category : 'installation' }
KGSession class >> installManifest: aDictionary sourceChanges: aSourceCapability persistence: aPersistenceCapability [
	<arg: #aDictionary type: #(Dictionary<String, Any>)>
	<arg: #aSourceCapability type: #Any>
	<arg: #aPersistenceCapability type: #Any>
	<return: #KGSession>
	Current ifNotNil: [ self error: 'A session is already installed' ].
	Current := self new
		initializeManifest: aDictionary
		sourceChanges: aSourceCapability
		persistence: aPersistenceCapability.
	^ Current
]

{ #category : 'accessing' }
KGSession class >> current [
	<return: #KGSession>
	Current ifNil: [ self error: 'No KlibGen session is installed' ].
	^ Current
]

{ #category : 'testing' }
KGSession class >> reset [
	<return: #KGSession>
	Current := nil.
	^ self
]

{ #category : 'initialization' }
KGSession >> initializeManifest: aDictionary sourceChanges: aSourceCapability persistence: aPersistenceCapability [
	<arg: #aDictionary type: #(Dictionary<String, Any>)>
	<arg: #aSourceCapability type: #Any>
	<arg: #aPersistenceCapability type: #Any>
	<return: #KGSession>
	manifest := aDictionary copy.
	sourceChanges := aSourceCapability.
	persistence := aPersistenceCapability.
	^ self
]

{ #category : 'accessing' }
KGSession >> id [
	<return: #String>
	^ manifest at: 'sessionId'
]

{ #category : 'accessing' }
KGSession >> manifest [
	<return: #(Dictionary<String, Any>)>
	^ manifest copy
]

{ #category : 'accessing' }
KGSession >> persistence [
	<return: #Any>
	^ persistence
]

{ #category : 'accessing' }
KGSession >> sourceChanges [
	<return: #Any>
	^ sourceChanges
]
