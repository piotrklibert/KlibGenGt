"
Write one JSON-compatible record through a same-directory temporary file.

- Slots
  - none
- Public API
  - {{gtMethod:KGAtomicJsonWriter class>>#write:to:}}
    Atomically replace the target with one STON-JSON record.
"
Class { #name : 'KGAtomicJsonWriter', #superclass : 'Object', #category : 'KlibGenGt-Session', #package : 'KlibGenGt-Session' }

{ #category : 'writing' }
KGAtomicJsonWriter class >> write: aDictionary to: aPath [
	<arg: #aDictionary type: #(Dictionary<String, Any>)>
	<arg: #aPath type: #(FileReference | String)>
	<return: #FileReference>
	| target temporary |
	target := aPath asFileReference.
	target parent ensureCreateDirectory.
	temporary := target parent / ('.', target basename, '.', UUID new asString, '.tmp').
	temporary writeStreamDo: [ :stream | stream nextPutAll: (STONJSON toString: aDictionary); lf ].
	target ensureDelete.
	temporary moveTo: target.
	^ target
]
