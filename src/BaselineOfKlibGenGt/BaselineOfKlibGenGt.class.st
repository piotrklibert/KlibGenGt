Class {
	#name : 'BaselineOfKlibGenGt',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfKlibGenGt',
	#package : 'BaselineOfKlibGenGt'
}

{ #category : 'baselines' }
BaselineOfKlibGenGt >> baseline: spec [
    <baseline>
	| sqliteRepository neoJSONRepository jsonSchemaRepository |
	sqliteRepository := Smalltalk os environment
		at: 'KLIBGEN_SQLITE_REPOSITORY'
		ifAbsent: [ 'github://pharo-rdbms/Pharo-SQLite3:44dee155676f9ac9be1c7ffac8caef90024968c4/src' ].
	neoJSONRepository := Smalltalk os environment
		at: 'KLIBGEN_NEOJSON_REPOSITORY'
		ifAbsent: [ 'github://svenvc/NeoJSON:11e274dd96dc9636cab90929937b7cd09719de7c/repository' ].
	jsonSchemaRepository := Smalltalk os environment
		at: 'KLIBGEN_JSONSCHEMA_REPOSITORY'
		ifAbsent: [ 'github://ApptiveGrid/JSONSchema:d6ac78c12ad66d582adc88d5f2c4f5ee6b0d78a7/source' ].

    spec for: #common do: [
        spec
            baseline: 'SQLite3' with: [
                spec
				repository: sqliteRepository;
                    loads: 'Core' ].
		spec
			baseline: 'NeoJSON' with: [
				spec
					repository: neoJSONRepository;
					loads: 'core' ].
		spec
			baseline: 'JSONSchema' with: [
				spec
					repository: jsonSchemaRepository;
					loads: 'Core' ].

        spec
            package: 'KlibGenGt-BuildSupport';
            package: 'KlibGenGt-Core';
            package: 'KlibGenGt-DB' with: [
                spec requires: #( 'KlibGenGt-Core' 'SQLite3' ) ];
            package: 'KlibGenGt-Examples' with: [
                spec requires: #( 'KlibGenGt-Core' ) ];
            package: 'KlibGenGt-Environment' with: [
                spec requires: #( 'KlibGenGt-Core' ) ];
            package: 'KlibGenGt-JsonModels' with: [
				spec requires: #( 'NeoJSON' 'JSONSchema' ) ];
            package: 'KlibGenGt-Kotlin' with: [
                spec requires: #( 'KlibGenGt-Core' ) ];
            package: 'KlibGenGt-Session' with: [
                spec requires: #( 'KlibGenGt-BuildSupport' 'KlibGenGt-JsonModels' ) ];
            package: 'KlibGenGt-Tools' with: [
                spec requires: #( 'KlibGenGt-Core' 'KlibGenGt-Session' ) ];
            package: 'KlibGenGt-Tests' with: [
                spec requires: #( 'KlibGenGt-Core' 'KlibGenGt-DB' 'KlibGenGt-Examples' 'KlibGenGt-Environment' 'KlibGenGt-Kotlin' 'KlibGenGt-Tools' ) ].

        spec
            group: 'Core' with: #( 'KlibGenGt-Core' );
            group: 'BuildSupport' with: #( 'KlibGenGt-BuildSupport' );
            group: 'DB' with: #( 'KlibGenGt-DB' );
            group: 'Examples' with: #( 'KlibGenGt-Examples' );
            group: 'Environment' with: #( 'KlibGenGt-Environment' );
            group: 'JsonModels' with: #( 'KlibGenGt-JsonModels' );
            group: 'Kotlin' with: #( 'KlibGenGt-Kotlin' );
            group: 'Session' with: #( 'KlibGenGt-Session' );
            group: 'Tools' with: #( 'KlibGenGt-Tools' );
            group: 'Tests' with: #( 'KlibGenGt-Tests' );
            group: 'default' with: #( 'Core' 'DB' 'Examples' 'Tools' );
            group: 'dev' with: #( 'BuildSupport' 'Core' 'DB' 'Examples' 'Environment' 'JsonModels' 'Kotlin' 'Session' 'Tools' 'Tests' );
            group: 'CI' with: #( 'dev' ) ]
]

{ #category : 'dependency analysis' }
BaselineOfKlibGenGt >> gtDependencyAnalysisPreloadedBaselines [
    "BaselineOfGToolkit is already present in the downloaded GT runtime. Including it here tells GT dependency analysis to treat the runtime baseline as preloaded instead of reporting it as a project dependency that should be fetched."

    ^ super gtDependencyAnalysisPreloadedBaselines copyWith: BaselineOfGToolkit
]
