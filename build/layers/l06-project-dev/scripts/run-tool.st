| runner request response exitCode output |
runner := KGToolRunner new.
[
	request := STONJSON fromString: (Smalltalk os environment at: 'KLIBGEN_TOOL_REQUEST').
	response := runner run: request
] on: Exception do: [ :error |
	response := runner failureFor: 'request' exception: error ].
exitCode := (response at: 'ok') ifTrue: [ 0 ] ifFalse: [ 1 ].
output := ZnCharacterWriteStream on: Stdio stdout encoding: 'utf8'.
output nextPutAll: (STONJSON toString: response); lf; flush.
Smalltalk exit: exitCode
