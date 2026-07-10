Class {
	#name : 'BaselineOfKlibGenGt',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfKlibGenGt',
	#package : 'BaselineOfKlibGenGt'
}

{ #category : 'baselines' }
BaselineOfKlibGenGt >> baseline: spec [
    <baseline>

    spec for: #common do: [
        spec
            package: 'KlibGenGt-Core';
            package: 'KlibGenGt-Examples' with: [
                spec requires: #( 'KlibGenGt-Core' ) ];
            package: 'KlibGenGt-Environment' with: [
                spec requires: #( 'KlibGenGt-Core' ) ];
            package: 'KlibGenGt-Kotlin' with: [
                spec requires: #( 'KlibGenGt-Core' ) ];
            package: 'KlibGenGt-Tests' with: [
                spec requires: #( 'KlibGenGt-Core' 'KlibGenGt-Examples' 'KlibGenGt-Environment' 'KlibGenGt-Kotlin' ) ].

        spec
            group: 'Core' with: #( 'KlibGenGt-Core' );
            group: 'Examples' with: #( 'KlibGenGt-Examples' );
            group: 'Environment' with: #( 'KlibGenGt-Environment' );
            group: 'Kotlin' with: #( 'KlibGenGt-Kotlin' );
            group: 'Tests' with: #( 'KlibGenGt-Tests' );
            group: 'default' with: #( 'Core' 'Examples' );
            group: 'dev' with: #( 'Core' 'Examples' 'Environment' 'Kotlin' 'Tests' );
            group: 'CI' with: #( 'dev' ) ]
]

{ #category : 'dependency analysis' }
BaselineOfKlibGenGt >> gtDependencyAnalysisPreloadedBaselines [
    "BaselineOfGToolkit is already present in the downloaded GT runtime. Including it here tells GT dependency analysis to treat the runtime baseline as preloaded instead of reporting it as a project dependency that should be fetched."

    ^ super gtDependencyAnalysisPreloadedBaselines copyWith: BaselineOfGToolkit
]
