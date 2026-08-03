"
Write one JSON-compatible record through a same-directory temporary file.

- Slots
  - none
- Public API
  - {{gtMethod:KGAtomicJsonWriter class>>#write:to:}}
    Atomically replace the target with one dictionary or generated JSON record.
"
Class {
	#name : 'KGAtomicJsonWriter',
	#superclass : 'Object',
	#category : 'KlibGenGt-Session',
	#package : 'KlibGenGt-Session'
}

{ #category : 'writing' }
KGAtomicJsonWriter class >> write: aRecord to: aPath [
	<arg: #aRecord type: #(KGJsonRecord | Dictionary<String, Any>)>
	<arg: #aPath type: #(FileReference | String)>
	<return: #FileReference>
	| target temporary dictionary |
	dictionary := (aRecord isKindOf: KGJsonRecord) ifTrue: [ aRecord asDictionary ] ifFalse: [ aRecord ].
	target := aPath asFileReference.
	target parent ensureCreateDirectory.
	temporary := target parent / ('.', target basename, '.', UUID new asString, '.tmp').
	temporary writeStreamDo: [ :stream | stream nextPutAll: (STONJSON toString: dictionary); lf ].
	target ensureDelete.
	temporary moveTo: target.
	^ target
]
