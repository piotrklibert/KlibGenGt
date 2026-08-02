"
Normalize one image operation into the stable schema-version-one response envelope.

- Slots
  - `value` (`#(Dictionary<String, Any>)`, `result`) - JSON-compatible response.
- Public API
  - {{gtMethod:KGOperationResult class>>#success:operation:}}
    Construct a successful response.
  - {{gtMethod:KGOperationResult class>>#failure:operation:}}
    Construct a failed response with bounded exception detail.
  - {{gtMethod:KGOperationResult>>#asDictionary}}
    Answer a defensive response copy.
"
Class { #name : 'KGOperationResult', #superclass : 'Object', #instVars : [ 'value' ], #category : 'KlibGenGt-Session', #package : 'KlibGenGt-Session' }

{ #category : 'instance creation' }
KGOperationResult class >> failure: anException operation: aString [
	<arg: #anException type: #Exception>
	<arg: #aString type: #String>
	<return: #KGOperationResult>
	^ self new initializeValue: (OrderedDictionary new at: 'schemaVersion' put: 1; at: 'ok' put: false; at: 'operation' put: aString; at: 'error' put: (OrderedDictionary new at: 'class' put: anException class name asString; at: 'message' put: anException messageText asString; yourself); yourself)
]

{ #category : 'instance creation' }
KGOperationResult class >> success: aDictionary operation: aString [
	<arg: #aDictionary type: #(Dictionary<String, Any>)>
	<arg: #aString type: #String>
	<return: #KGOperationResult>
	^ self new initializeValue: (OrderedDictionary new at: 'schemaVersion' put: 1; at: 'ok' put: true; at: 'operation' put: aString; at: 'data' put: aDictionary; yourself)
]

{ #category : 'accessing' }
KGOperationResult >> asDictionary [ <return: #(Dictionary<String, Any>)> ^ value copy ]

{ #category : 'initialization' }
KGOperationResult >> initializeValue: aDictionary [ <arg: #aDictionary type: #(Dictionary<String, Any>)> <return: #KGOperationResult> value := aDictionary. ^ self ]
