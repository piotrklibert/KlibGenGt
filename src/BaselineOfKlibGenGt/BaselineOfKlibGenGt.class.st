Class {
	#name : 'BaselineOfKlibGenGt',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfKlibGenGt',
	#package : 'BaselineOfKlibGenGt'
}

{ #category : 'baselines' }
BaselineOfKlibGenGt >> baseline: spec [
    <baseline>
	| sqliteRepository |
	sqliteRepository := Smalltalk os environment
		at: 'KLIBGEN_SQLITE_REPOSITORY'
		ifAbsent: [ 'github://pharo-rdbms/Pharo-SQLite3:44dee155676f9ac9be1c7ffac8caef90024968c4/src' ].

    spec for: #common do: [
        spec
            baseline: 'SQLite3' with: [
                spec
				repository: sqliteRepository;
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
            package: 'KlibGenGt-JsonModels';
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
