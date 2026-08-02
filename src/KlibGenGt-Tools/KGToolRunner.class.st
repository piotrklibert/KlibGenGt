"
Dispatch structured CLI requests to the project image tools and normalize failures.

- Slots
  - none
- Public API
  - {{gtMethod:KGToolRunner>>#run:}}
    Execute one request and answer the versioned JSON-compatible response envelope.
"
Class {
	#name : 'KGToolRunner',
	#superclass : 'Object',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'running' }
KGToolRunner >> run: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| operation data |
	operation := aRequest at: 'operation' ifAbsent: [ self error: 'request is missing operation' ].
	^ [ data := self dispatch: operation request: aRequest.
		((operation beginsWith: 'test.') and: [ (data at: 'successful' ifAbsent: [ true ]) not ])
			ifTrue: [ OrderedDictionary new at: 'schemaVersion' put: 1; at: 'ok' put: false; at: 'operation' put: operation; at: 'data' put: data; yourself ]
			ifFalse: [ self successFor: operation data: data ] ]
		on: Exception
		do: [ :error | self failureFor: operation exception: error ]
]

{ #category : 'private - dispatching' }
KGToolRunner >> dispatch: operation request: aRequest [
	^ (KGToolRegistry default at: operation) execute: aRequest
]

{ #category : 'private - responses' }
KGToolRunner >> failureFor: operation exception: anException [
	| stack kind |
	stack := anException signalerContext
		ifNil: [ #() ]
		ifNotNil: [ :context | context shortDebugStack lines ].
	kind := ((anException class name includesSubstring: 'Syntax')
		or: [ anException class name includesSubstring: 'Notice' ])
		ifTrue: [ 'compile' ]
		ifFalse: [ 'runtime' ].
	^ OrderedDictionary new
		at: 'schemaVersion' put: 1;
		at: 'ok' put: false;
		at: 'operation' put: operation;
		at: 'error' put: (OrderedDictionary new
			at: 'kind' put: kind;
			at: 'class' put: anException class name asString;
			at: 'message' put: anException messageText;
			at: 'stack' put: stack;
			yourself);
		yourself
]

{ #category : 'private - responses' }
KGToolRunner >> successFor: operation data: data [
	^ OrderedDictionary new
		at: 'schemaVersion' put: 1;
		at: 'ok' put: true;
		at: 'operation' put: operation;
		at: 'data' put: data;
		yourself
]
