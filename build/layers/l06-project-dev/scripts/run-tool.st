| runner request response exitCode output resultsPath |
runner := KGToolRunner new.
[
	request := STONJSON fromString: (Smalltalk os environment at: 'KLIBGEN_TOOL_REQUEST').
	response := runner run: request
] on: Exception do: [ :error |
	response := runner failureFor: 'request' exception: error ].
(response at: 'ok') ifTrue: [
	(response at: 'operation') = 'test.run' ifTrue: [
		resultsPath := Smalltalk os environment at: 'KLIBGEN_TEST_RESULTS_PATH' ifAbsent: [ nil ].
		resultsPath ifNotNil: [
			resultsPath asFileReference parent ensureCreateDirectory.
			resultsPath asFileReference writeStreamDo: [ :stream |
				stream nextPutAll: (STONJSON toString: (response at: 'data')); lf ] ] ] ].
exitCode := ((response at: 'ok') and: [
	(response at: 'operation') ~= 'test.run' or: [
		(response at: 'data') at: 'successful' ] ]) ifTrue: [ 0 ] ifFalse: [ 1 ].
output := ZnCharacterWriteStream on: Stdio stdout encoding: 'utf8'.
output nextPutAll: (STONJSON toString: response); lf; flush.
Smalltalk exit: exitCode
