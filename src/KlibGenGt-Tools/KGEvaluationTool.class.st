"
Evaluate Smalltalk expressions for CLI clients with optional sampling-profiler output.

- Slots
  - none
- Public API
  - {{gtMethod:KGEvaluationTool>>#evaluate:}}
    Evaluate the requested expression and answer its printed result and optional profile metrics.
"
Class {
	#name : 'KGEvaluationTool',
	#superclass : 'Object',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'evaluating' }
KGEvaluationTool >> evaluate: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| expression profiling result profiler report data |
	expression := aRequest at: 'expression'.
	profiling := aRequest at: 'profile' ifAbsent: [ false ].
	profiling
		ifTrue: [
			profiler := AndreasSystemProfiler new.
			profiler spyOn: [ result := Smalltalk compiler evaluate: expression ].
			report := String streamContents: [ :stream | profiler report: stream ] ]
		ifFalse: [ result := Smalltalk compiler evaluate: expression ].
	data := OrderedDictionary new
		at: 'result' put: result printString;
		yourself.
	profiling ifTrue: [
		data at: 'profile' put: (OrderedDictionary new
			at: 'totalTimeMs' put: profiler totalTime;
			at: 'sampleCount' put: profiler totalTally;
			at: 'report' put: report;
			yourself) ].
	^ data
]
