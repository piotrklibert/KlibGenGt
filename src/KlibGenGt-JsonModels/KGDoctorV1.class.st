"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `DoctorV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `operation` (`#String`, `accessing`) - Value of JSON field `operation`.
  - `ok` (`#Boolean`, `accessing`) - Value of JSON field `ok`.
  - `platform` (`#String`, `accessing`) - Value of JSON field `platform`.
  - `stateRoot` (`#String`, `accessing`) - Value of JSON field `stateRoot`.
  - `tools` (`#(Array<KGJsonToolCheckRecord>)`, `accessing`) - Value of JSON field `tools`.
  - `checks` (`#(Array<KGJsonToolCheckRecord>)`, `accessing`) - Value of JSON field `checks`.
- Public API
  - {{gtMethod:KGDoctorV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGDoctorV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGDoctorV1>>#operation}}
    Answer the immutable `operation` field value.
  - {{gtMethod:KGDoctorV1>>#ok}}
    Answer the immutable `ok` field value.
  - {{gtMethod:KGDoctorV1>>#platform}}
    Answer the immutable `platform` field value.
  - {{gtMethod:KGDoctorV1>>#stateRoot}}
    Answer the immutable `stateRoot` field value.
  - {{gtMethod:KGDoctorV1>>#tools}}
    Answer the immutable `tools` field value.
  - {{gtMethod:KGDoctorV1>>#checks}}
    Answer the immutable `checks` field value."
Class {
	#name : 'KGDoctorV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'operation',
		'ok',
		'platform',
		'stateRoot',
		'tools',
		'checks'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGDoctorV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGDoctorV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.doctor/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('operation' 'operation' true #(#literal #('doctor'))).
		#('ok' 'ok' true #(#boolean)).
		#('platform' 'platform' true #(#string)).
		#('stateRoot' 'stateRoot' true #(#string)).
		#('tools' 'tools' true #(#array #(#model #KGJsonToolCheckRecord))).
		#('checks' 'checks' true #(#array #(#model #KGJsonToolCheckRecord))) }
]

{ #category : 'json schema' }
KGDoctorV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.doctor/1'
]

{ #category : 'accessing' }
KGDoctorV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGDoctorV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGDoctorV1 >> operation [
	<return: #String>
	^ self defensiveJsonValue: operation
]

{ #category : 'accessing' }
KGDoctorV1 >> ok [
	<return: #Boolean>
	^ self defensiveJsonValue: ok
]

{ #category : 'accessing' }
KGDoctorV1 >> platform [
	<return: #String>
	^ self defensiveJsonValue: platform
]

{ #category : 'accessing' }
KGDoctorV1 >> stateRoot [
	<return: #String>
	^ self defensiveJsonValue: stateRoot
]

{ #category : 'accessing' }
KGDoctorV1 >> tools [
	<return: #(Array<KGJsonToolCheckRecord>)>
	^ self defensiveJsonValue: tools
]

{ #category : 'accessing' }
KGDoctorV1 >> checks [
	<return: #(Array<KGJsonToolCheckRecord>)>
	^ self defensiveJsonValue: checks
]
