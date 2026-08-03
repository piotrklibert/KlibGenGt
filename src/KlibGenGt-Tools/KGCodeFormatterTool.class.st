"
Format syntactically valid Pharo source supplied as a method body without compiling or mutating project source.

- Slots
  - none
- Public API
  - {{gtMethod:KGCodeFormatterTool>>#format:}}
    Parse the request's `source` as a method body and answer LF-normalized formatted text plus formatter metadata.
"
Class {
	#name : 'KGCodeFormatterTool',
	#superclass : 'Object',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'formatting' }
KGCodeFormatterTool >> format: aRequest [
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #(Dictionary<String, Any>)>
	| source ast formatted |
	source := aRequest at: 'source'.
	source isString ifFalse: [ self error: 'source must be a string' ].
	ast := RBParser parseExpression: source.
	formatted := ast formattedCode withLineEndings: String lf.
	^ OrderedDictionary new
		at: 'text' put: formatted;
		at: 'changed' put: formatted ~= source;
		at: 'formatter' put: RBProgramNode formatterClass name asString;
		at: 'mode' put: 'method-body';
		yourself
]
