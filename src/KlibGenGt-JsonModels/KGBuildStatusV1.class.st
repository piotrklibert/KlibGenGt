"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `BuildStatusV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#(Integer | UndefinedObject)`, `accessing`) - Value of JSON field `schemaVersion`.
  - `state` (`#String`, `accessing`) - Value of JSON field `state`.
  - `outputKey` (`#String`, `accessing`) - Value of JSON field `outputKey`.
  - `role` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `role`.
  - `artifactPath` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `artifactPath`.
  - `error` (`#(KGJsonErrorRecord | UndefinedObject)`, `accessing`) - Value of JSON field `error`.
  - `failedAt` (`#(Number | UndefinedObject)`, `accessing`) - Value of JSON field `failedAt`.
  - `diagnosticPath` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `diagnosticPath`.
  - `path` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `path`.
  - `storage` (`#(KGJsonStorageRecord | UndefinedObject)`, `accessing`) - Value of JSON field `storage`.
- Public API
  - {{gtMethod:KGBuildStatusV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGBuildStatusV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGBuildStatusV1>>#state}}
    Answer the immutable `state` field value.
  - {{gtMethod:KGBuildStatusV1>>#outputKey}}
    Answer the immutable `outputKey` field value.
  - {{gtMethod:KGBuildStatusV1>>#role}}
    Answer the immutable `role` field value.
  - {{gtMethod:KGBuildStatusV1>>#artifactPath}}
    Answer the immutable `artifactPath` field value.
  - {{gtMethod:KGBuildStatusV1>>#error}}
    Answer the immutable `error` field value.
  - {{gtMethod:KGBuildStatusV1>>#failedAt}}
    Answer the immutable `failedAt` field value.
  - {{gtMethod:KGBuildStatusV1>>#diagnosticPath}}
    Answer the immutable `diagnosticPath` field value.
  - {{gtMethod:KGBuildStatusV1>>#path}}
    Answer the immutable `path` field value.
  - {{gtMethod:KGBuildStatusV1>>#storage}}
    Answer the immutable `storage` field value.
"
Class {
	#name : 'KGBuildStatusV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'state',
		'outputKey',
		'role',
		'artifactPath',
		'error',
		'failedAt',
		'diagnosticPath',
		'path',
		'storage'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGBuildStatusV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ true
]

{ #category : 'json schema' }
KGBuildStatusV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.build-status/1'))).
		#('schemaVersion' 'schemaVersion' false #(#union #(#(#literal #(1)) #(#nil)))).
		#('state' 'state' true #(#literal #('building' 'succeeded' 'failed'))).
		#('outputKey' 'outputKey' true #(#string)).
		#('role' 'role' false #(#union #(#(#string) #(#nil)))).
		#('artifactPath' 'artifactPath' false #(#union #(#(#string) #(#nil)))).
		#('error' 'error' false #(#union #(#(#model #KGJsonErrorRecord) #(#nil)))).
		#('failedAt' 'failedAt' false #(#union #(#(#number) #(#nil)))).
		#('diagnosticPath' 'diagnosticPath' false #(#union #(#(#string) #(#nil)))).
		#('path' 'path' false #(#union #(#(#string) #(#nil)))).
		#('storage' 'storage' false #(#union #(#(#model #KGJsonStorageRecord) #(#nil)))) }
]

{ #category : 'json schema' }
KGBuildStatusV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.build-status/1'
]

{ #category : 'accessing' }
KGBuildStatusV1 >> artifactPath [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: artifactPath
]

{ #category : 'accessing' }
KGBuildStatusV1 >> diagnosticPath [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: diagnosticPath
]

{ #category : 'accessing' }
KGBuildStatusV1 >> error [
	<return: #(KGJsonErrorRecord | UndefinedObject)>
	^ self defensiveJsonValue: error
]

{ #category : 'accessing' }
KGBuildStatusV1 >> failedAt [
	<return: #(Number | UndefinedObject)>
	^ self defensiveJsonValue: failedAt
]

{ #category : 'accessing' }
KGBuildStatusV1 >> outputKey [
	<return: #String>
	^ self defensiveJsonValue: outputKey
]

{ #category : 'accessing' }
KGBuildStatusV1 >> path [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: path
]

{ #category : 'accessing' }
KGBuildStatusV1 >> role [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: role
]

{ #category : 'accessing' }
KGBuildStatusV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGBuildStatusV1 >> schemaVersion [
	<return: #(Integer | UndefinedObject)>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGBuildStatusV1 >> state [
	<return: #String>
	^ self defensiveJsonValue: state
]

{ #category : 'accessing' }
KGBuildStatusV1 >> storage [
	<return: #(KGJsonStorageRecord | UndefinedObject)>
	^ self defensiveJsonValue: storage
]
