| source |

source := 'startUp: isANewSession
	(isANewSession
		and: [ Smalltalk isHeadless not
		and: [ self hasModule ] ])
		ifTrue: [
			self initEnvLogger.
			self initGtk ]'.

GtWebViewLibrary class compile: source classified: #'system startup'.

Stdio stdout
	nextPutAll: 'Patched GtWebViewLibrary class>>startUp: for headless execution.';
	lf;
	flush.

Smalltalk snapshot: true andQuit: true
