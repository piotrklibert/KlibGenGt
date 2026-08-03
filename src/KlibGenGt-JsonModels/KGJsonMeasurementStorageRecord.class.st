"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `MeasurementStorageRecord`.

- Slots
  - `logicalBytes` (`#Integer`, `accessing`) - Value of JSON field `logicalBytes`.
  - `allocatedBytes` (`#Integer`, `accessing`) - Value of JSON field `allocatedBytes`.
  - `files` (`#(Dictionary<String, KGJsonSuffixStorageRecord>)`, `accessing`) - Value of JSON field `files`.
- Public API
  - {{gtMethod:KGJsonMeasurementStorageRecord>>#logicalBytes}}
    Answer the immutable `logicalBytes` field value.
  - {{gtMethod:KGJsonMeasurementStorageRecord>>#allocatedBytes}}
    Answer the immutable `allocatedBytes` field value.
  - {{gtMethod:KGJsonMeasurementStorageRecord>>#files}}
    Answer the immutable `files` field value.
"
Class {
	#name : 'KGJsonMeasurementStorageRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'logicalBytes',
		'allocatedBytes',
		'files'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonMeasurementStorageRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonMeasurementStorageRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('logicalBytes' 'logicalBytes' true #(#constrained #(#integer) #(#(#ge 0)))).
		#('allocatedBytes' 'allocatedBytes' true #(#constrained #(#integer) #(#(#ge 0)))).
		#('files' 'files' true #(#dictionary #(#model #KGJsonSuffixStorageRecord))) }
]

{ #category : 'json schema' }
KGJsonMeasurementStorageRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonMeasurementStorageRecord >> allocatedBytes [
	<return: #Integer>
	^ self defensiveJsonValue: allocatedBytes
]

{ #category : 'accessing' }
KGJsonMeasurementStorageRecord >> files [
	<return: #(Dictionary<String, KGJsonSuffixStorageRecord>)>
	^ self defensiveJsonValue: files
]

{ #category : 'accessing' }
KGJsonMeasurementStorageRecord >> logicalBytes [
	<return: #Integer>
	^ self defensiveJsonValue: logicalBytes
]
