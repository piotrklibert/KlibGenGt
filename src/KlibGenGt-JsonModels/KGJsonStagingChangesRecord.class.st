"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `StagingChangesRecord`.

- Slots
  - `additions` (`#(Array<String>)`, `accessing`) - Value of JSON field `additions`.
  - `modifications` (`#(Array<String>)`, `accessing`) - Value of JSON field `modifications`.
  - `removals` (`#(Array<String>)`, `accessing`) - Value of JSON field `removals`.
  - `renames` (`#(Array<KGJsonRenameRecord>)`, `accessing`) - Value of JSON field `renames`.
  - `prohibited` (`#(Array<String>)`, `accessing`) - Value of JSON field `prohibited`.
- Public API
  - {{gtMethod:KGJsonStagingChangesRecord>>#additions}}
    Answer the immutable `additions` field value.
  - {{gtMethod:KGJsonStagingChangesRecord>>#modifications}}
    Answer the immutable `modifications` field value.
  - {{gtMethod:KGJsonStagingChangesRecord>>#removals}}
    Answer the immutable `removals` field value.
  - {{gtMethod:KGJsonStagingChangesRecord>>#renames}}
    Answer the immutable `renames` field value.
  - {{gtMethod:KGJsonStagingChangesRecord>>#prohibited}}
    Answer the immutable `prohibited` field value."
Class {
	#name : 'KGJsonStagingChangesRecord',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'additions',
		'modifications',
		'removals',
		'renames',
		'prohibited'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGJsonStagingChangesRecord class >> jsonAllowsExtras [
	<return: #Boolean>
	^ false
]

{ #category : 'json schema' }
KGJsonStagingChangesRecord class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('additions' 'additions' true #(#array #(#string))).
		#('modifications' 'modifications' true #(#array #(#string))).
		#('removals' 'removals' true #(#array #(#string))).
		#('renames' 'renames' true #(#array #(#model #KGJsonRenameRecord))).
		#('prohibited' 'prohibited' true #(#array #(#string))) }
]

{ #category : 'json schema' }
KGJsonStagingChangesRecord class >> jsonSchemaName [
	<return: #(String?)>
	^ nil
]

{ #category : 'accessing' }
KGJsonStagingChangesRecord >> additions [
	<return: #(Array<String>)>
	^ self defensiveJsonValue: additions
]

{ #category : 'accessing' }
KGJsonStagingChangesRecord >> modifications [
	<return: #(Array<String>)>
	^ self defensiveJsonValue: modifications
]

{ #category : 'accessing' }
KGJsonStagingChangesRecord >> removals [
	<return: #(Array<String>)>
	^ self defensiveJsonValue: removals
]

{ #category : 'accessing' }
KGJsonStagingChangesRecord >> renames [
	<return: #(Array<KGJsonRenameRecord>)>
	^ self defensiveJsonValue: renames
]

{ #category : 'accessing' }
KGJsonStagingChangesRecord >> prohibited [
	<return: #(Array<String>)>
	^ self defensiveJsonValue: prohibited
]
