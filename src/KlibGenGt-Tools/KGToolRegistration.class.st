"
Describe one versioned image tool and its compatibility requirements.

- Slots
  - `identifier` (`#String`, `identity`) - Stable request operation.
  - `version` (`#Integer`, `identity`) - Registration protocol version.
  - `handler` (`#(Dictionary<String, Any> -> Dictionary<String, Any>)`, `dispatch`) - Tool execution block.
  - `frontends` (`#(Array<String>)`, `compatibility`) - Supported frontend names.
  - `requiredCapabilities` (`#(Array<String>)`, `compatibility`) - Required capability names.
- Public API
  - {{gtMethod:KGToolRegistration class>>#identifier:version:frontends:capabilities:handler:}}
    Construct a complete immutable registration.
  - {{gtMethod:KGToolRegistration>>#execute:}}
    Execute the handler for one validated request.
  - {{gtMethod:KGToolRegistration>>#identifier}}
    Answer the stable operation identifier.
  - {{gtMethod:KGToolRegistration>>#execute:inSession:}}
    Validate the session frontend and capabilities before executing the handler.
  - {{gtMethod:KGToolRegistration>>#frontends}}
    Answer the permitted frontend names.
  - {{gtMethod:KGToolRegistration>>#requiredCapabilities}}
    Answer the capability names required for execution.
  - {{gtMethod:KGToolRegistration>>#version}}
    Answer the registration protocol version.
"
Class {
	#name : 'KGToolRegistration',
	#superclass : 'Object',
	#instVars : [
		'identifier',
		'version',
		'handler',
		'frontends',
		'requiredCapabilities'
	],
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'instance creation' }
KGToolRegistration class >> identifier: anIdentifier version: aVersion frontends: frontendNames capabilities: capabilityNames handler: aBlock [
	<arg: #anIdentifier type: #String> <arg: #aVersion type: #Integer>
	<arg: #frontendNames type: #(Array<String>)> <arg: #capabilityNames type: #(Array<String>)>
	<arg: #aBlock type: #((Dictionary<String, Any>) -> (Dictionary<String, Any>))>
	<return: #KGToolRegistration>
	^ self new initializeIdentifier: anIdentifier version: aVersion frontends: frontendNames capabilities: capabilityNames handler: aBlock
]

{ #category : 'executing' }
KGToolRegistration >> execute: aRequest [ <arg: #aRequest type: #(Dictionary<String, Any>)> <return: #(Dictionary<String, Any>)> ^ handler value: aRequest
]

{ #category : 'executing' }
KGToolRegistration >> execute: aRequest inSession: aSession [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<arg: #aSession type: #(KGSession?)>
	<return: #(Dictionary<String, Any>)>
	| preset |
	aSession ifNil: [
		requiredCapabilities ifNotEmpty: [ self error: 'image tool requires an installed session capability' ].
		^ self execute: aRequest ].
	preset := aSession manifest preset.
	(frontends includes: preset frontend) ifFalse: [
		self error: 'image tool is unavailable for frontend: ', preset frontend ].
	requiredCapabilities do: [ :capability |
		(capability = 'staged-source' and: [ preset sourceChanges = 'staged' ]) ifFalse: [
			self error: 'image tool requires capability: ', capability ] ].
	^ self execute: aRequest
]

{ #category : 'accessing' }
KGToolRegistration >> frontends [
	<return: #(Array<String>)>
	^ frontends copy
]

{ #category : 'accessing' }
KGToolRegistration >> identifier [ <return: #String> ^ identifier
]

{ #category : 'initialization' }
KGToolRegistration >> initializeIdentifier: anIdentifier version: aVersion frontends: frontendNames capabilities: capabilityNames handler: aBlock [
	<arg: #anIdentifier type: #String> <arg: #aVersion type: #Integer>
	<arg: #frontendNames type: #(Array<String>)> <arg: #capabilityNames type: #(Array<String>)>
	<arg: #aBlock type: #((Dictionary<String, Any>) -> (Dictionary<String, Any>))>
	<return: #KGToolRegistration>
	identifier := anIdentifier. version := aVersion. frontends := frontendNames copy.
	requiredCapabilities := capabilityNames copy. handler := aBlock. ^ self
]

{ #category : 'accessing' }
KGToolRegistration >> requiredCapabilities [
	<return: #(Array<String>)>
	^ requiredCapabilities copy
]

{ #category : 'accessing' }
KGToolRegistration >> version [
	<return: #Integer>
	^ version
]
