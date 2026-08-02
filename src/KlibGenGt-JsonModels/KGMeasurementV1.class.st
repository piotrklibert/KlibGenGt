"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `MeasurementV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `operation` (`#String`, `accessing`) - Value of JSON field `operation`.
  - `exitCode` (`#Integer`, `accessing`) - Value of JSON field `exitCode`.
  - `wallSeconds` (`#Number`, `accessing`) - Value of JSON field `wallSeconds`.
  - `before` (`#KGJsonMeasurementStorageRecord`, `accessing`) - Value of JSON field `before`.
  - `after` (`#KGJsonMeasurementStorageRecord`, `accessing`) - Value of JSON field `after`.
  - `logicalByteDelta` (`#Integer`, `accessing`) - Value of JSON field `logicalByteDelta`.
  - `allocatedByteDelta` (`#Integer`, `accessing`) - Value of JSON field `allocatedByteDelta`.
- Public API
  - {{gtMethod:KGMeasurementV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGMeasurementV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGMeasurementV1>>#operation}}
    Answer the immutable `operation` field value.
  - {{gtMethod:KGMeasurementV1>>#exitCode}}
    Answer the immutable `exitCode` field value.
  - {{gtMethod:KGMeasurementV1>>#wallSeconds}}
    Answer the immutable `wallSeconds` field value.
  - {{gtMethod:KGMeasurementV1>>#before}}
    Answer the immutable `before` field value.
  - {{gtMethod:KGMeasurementV1>>#after}}
    Answer the immutable `after` field value.
  - {{gtMethod:KGMeasurementV1>>#logicalByteDelta}}
    Answer the immutable `logicalByteDelta` field value.
  - {{gtMethod:KGMeasurementV1>>#allocatedByteDelta}}
    Answer the immutable `allocatedByteDelta` field value."
Class {
	#name : 'KGMeasurementV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'operation',
		'exitCode',
		'wallSeconds',
		'before',
		'after',
		'logicalByteDelta',
		'allocatedByteDelta'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGMeasurementV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGMeasurementV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.measurement/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('operation' 'operation' true #(#string)).
		#('exitCode' 'exitCode' true #(#integer)).
		#('wallSeconds' 'wallSeconds' true #(#constrained #(#number) #(#(#ge 0)))).
		#('before' 'before' true #(#model #KGJsonMeasurementStorageRecord)).
		#('after' 'after' true #(#model #KGJsonMeasurementStorageRecord)).
		#('logicalByteDelta' 'logicalByteDelta' true #(#integer)).
		#('allocatedByteDelta' 'allocatedByteDelta' true #(#integer)) }
]

{ #category : 'json schema' }
KGMeasurementV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.measurement/1'
]

{ #category : 'accessing' }
KGMeasurementV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGMeasurementV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGMeasurementV1 >> operation [
	<return: #String>
	^ self defensiveJsonValue: operation
]

{ #category : 'accessing' }
KGMeasurementV1 >> exitCode [
	<return: #Integer>
	^ self defensiveJsonValue: exitCode
]

{ #category : 'accessing' }
KGMeasurementV1 >> wallSeconds [
	<return: #Number>
	^ self defensiveJsonValue: wallSeconds
]

{ #category : 'accessing' }
KGMeasurementV1 >> before [
	<return: #KGJsonMeasurementStorageRecord>
	^ self defensiveJsonValue: before
]

{ #category : 'accessing' }
KGMeasurementV1 >> after [
	<return: #KGJsonMeasurementStorageRecord>
	^ self defensiveJsonValue: after
]

{ #category : 'accessing' }
KGMeasurementV1 >> logicalByteDelta [
	<return: #Integer>
	^ self defensiveJsonValue: logicalByteDelta
]

{ #category : 'accessing' }
KGMeasurementV1 >> allocatedByteDelta [
	<return: #Integer>
	^ self defensiveJsonValue: allocatedByteDelta
]
