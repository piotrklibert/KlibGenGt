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
	| operation |
	operation := aRequest at: 'operation' ifAbsent: [ self error: 'request is missing operation' ].
	^ [ self
		successFor: operation
		data: (self dispatch: operation request: aRequest) ]
		on: Exception
		do: [ :error | self failureFor: operation exception: error ]
]

{ #category : 'private - dispatching' }
KGToolRunner >> dispatch: operation request: aRequest [
	operation = 'code.search' ifTrue: [ ^ KGCodeSearchTool new search: aRequest ].
	operation = 'code.class' ifTrue: [ ^ KGCodeSearchTool new classDefinition: aRequest ].
	operation = 'code.method' ifTrue: [ ^ KGCodeSearchTool new methodSource: aRequest ].
	operation = 'lepiter.search' ifTrue: [ ^ KGLepiterTool new search: aRequest ].
	operation = 'lepiter.export' ifTrue: [ ^ KGLepiterTool new export: aRequest ].
	operation = 'eval' ifTrue: [ ^ KGEvaluationTool new evaluate: aRequest ].
	operation = 'test.run' ifTrue: [ ^ KGTestTool new run: aRequest ].
	self error: 'unknown image tool operation: ' , operation
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
