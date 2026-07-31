| metadataFile manifestsJson digest profile metadataClass |
metadataFile := Smalltalk os environment at: 'KLIBGEN_MANIFESTS_FILE'.
manifestsJson := metadataFile asFileReference contents.
digest := Smalltalk os environment at: 'KLIBGEN_MANIFESTS_DIGEST'.
profile := Smalltalk os environment at: 'KLIBGEN_PROFILE'.

metadataClass := Smalltalk at: #KlibGenBuildMetadata ifAbsent: [
    Object
        subclass: #KlibGenBuildMetadata
        instanceVariableNames: ''
        classVariableNames: 'Manifests Digest Profile'
        package: 'KlibGen-Build-Metadata' ].
metadataClass comment: 'Generated query API for canonical host-side build manifests. Do not edit this class in an image; rebuild it from JSON.'.
metadataClass class compile: 'installJson: aString digest: aDigest profile: aProfile
    Manifests := NeoJSONReader fromString: aString.
    Digest := aDigest.
    Profile := aProfile' classified: 'installation'.
metadataClass class compile: 'manifestForLayer: aLayerId
    ^ Manifests detect: [ :each | (each at: ''layerId'') = aLayerId ] ifNone: [ nil ]' classified: 'accessing'.
metadataClass class compile: 'manifests
    ^ Manifests copy' classified: 'accessing'.
metadataClass class compile: 'digest
    ^ Digest' classified: 'accessing'.
metadataClass class compile: 'profile
    ^ Profile' classified: 'accessing'.
metadataClass installJson: manifestsJson digest: digest profile: profile.
Stdio stdout nextPutAll: 'Installed build metadata for '; nextPutAll: profile; lf; flush.
Smalltalk snapshot: true andQuit: true
