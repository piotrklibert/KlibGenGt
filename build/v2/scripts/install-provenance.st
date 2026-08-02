| manifestPath manifest projectKey |
manifestPath := (Smalltalk os environment at: 'KLIBGEN_BUILD_MANIFEST') asFileReference.
manifest := STONJSON fromString: manifestPath contents.
projectKey := Smalltalk os environment at: 'KLIBGEN_PROJECT_KEY'.
KGBuildProvenance installManifest: manifest projectKey: projectKey.
Stdio stdout nextPutAll: 'Installed v0.2 build provenance '; nextPutAll: projectKey; lf; flush.
Smalltalk snapshot: true andQuit: true
