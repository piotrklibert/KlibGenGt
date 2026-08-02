"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `SuffixStorageRecord`.

- Slots
  - `count` (`#Integer`, `accessing`) - Value of JSON field `count`.
  - `logicalBytes` (`#Integer`, `accessing`) - Value of JSON field `logicalBytes`.
- Public API
  - {{gtMethod:KGJsonSuffixStorageRecord>>#count}}
    Answer the immutable `count` field value.
  - {{gtMethod:KGJsonSuffixStorageRecord>>#logicalBytes}}
    Answer the immutable `logicalBytes` field value."
Class {
	#name : 'KGJsonSuffixStorageRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'count',
		'logicalBytes'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonSuffixStorageRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonSuffixStorageRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('count' 'count' true #(#constrained #(#integer) #(#(#ge 0)))).
		#('logicalBytes' 'logicalBytes' true #(#constrained #(#integer) #(#(#ge 0)))) }
]

{ #category : 'json schema' }
KGJsonSuffixStorageRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonSuffixStorageRecord >> count [
	<return: #Integer>
	^ self defensiveJsonValue: count
]

{ #category : 'accessing' }
KGJsonSuffixStorageRecord >> logicalBytes [
	<return: #Integer>
	^ self defensiveJsonValue: logicalBytes
]
