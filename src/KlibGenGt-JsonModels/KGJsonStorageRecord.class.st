"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `StorageRecord`.

- Slots
  - `logicalBytes` (`#Integer`, `accessing`) - Value of JSON field `logicalBytes`.
  - `allocatedBytes` (`#Integer`, `accessing`) - Value of JSON field `allocatedBytes`.
  - `fileCount` (`#Integer`, `accessing`) - Value of JSON field `fileCount`.
- Public API
  - {{gtMethod:KGJsonStorageRecord>>#logicalBytes}}
    Answer the immutable `logicalBytes` field value.
  - {{gtMethod:KGJsonStorageRecord>>#allocatedBytes}}
    Answer the immutable `allocatedBytes` field value.
  - {{gtMethod:KGJsonStorageRecord>>#fileCount}}
    Answer the immutable `fileCount` field value."
Class {
	#name : 'KGJsonStorageRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'logicalBytes',
		'allocatedBytes',
		'fileCount'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonStorageRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonStorageRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('logicalBytes' 'logicalBytes' true #(#constrained #(#integer) #(#(#ge 0)))).
		#('allocatedBytes' 'allocatedBytes' true #(#constrained #(#integer) #(#(#ge 0)))).
		#('fileCount' 'fileCount' true #(#constrained #(#integer) #(#(#ge 0)))) }
]

{ #category : 'json schema' }
KGJsonStorageRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonStorageRecord >> logicalBytes [
	<return: #Integer>
	^ self defensiveJsonValue: logicalBytes
]

{ #category : 'accessing' }
KGJsonStorageRecord >> allocatedBytes [
	<return: #Integer>
	^ self defensiveJsonValue: allocatedBytes
]

{ #category : 'accessing' }
KGJsonStorageRecord >> fileCount [
	<return: #Integer>
	^ self defensiveJsonValue: fileCount
]
