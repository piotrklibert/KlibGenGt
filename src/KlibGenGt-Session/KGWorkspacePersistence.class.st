"
Enforce save-or-discard lifecycle for the single mutable GUI workspace.

- Slots
  - none
- Public API
  - {{gtMethod:KGWorkspacePersistence>>#available}}
    Answer true because workspace persistence is enabled.
  - {{gtMethod:KGWorkspacePersistence>>#saveAndQuit}}
    Write authoritative saved completion, snapshot, and quit.
  - {{gtMethod:KGWorkspacePersistence>>#discardAndQuit}}
    Write authoritative discarded completion and quit without saving.
"
Class {
	#name : 'KGWorkspacePersistence',
	#superclass : 'Object',
	#category : 'KlibGenGt-Session',
	#package : 'KlibGenGt-Session'
}

{ #category : 'testing' }
KGWorkspacePersistence >> available [ <return: #Boolean> ^ true
]

{ #category : 'actions' }
KGWorkspacePersistence >> discardAndQuit [
	<return: #Nothing>
	self writeCompletion: 'discarded'. Smalltalk snapshot: false andQuit: true
]

{ #category : 'actions' }
KGWorkspacePersistence >> saveAndQuit [
	<return: #Nothing>
	self writeCompletion: 'saved'. Smalltalk snapshot: true andQuit: true
]

{ #category : 'private - writing' }
KGWorkspacePersistence >> writeCompletion: state [
	<arg: #state type: #String> <return: #KGWorkspacePersistence>
	| session path |
	session := KGSession current.
	path := session manifest paths completion.
	KGAtomicJsonWriter write: (KGSessionCompletionV1 fromDictionary: (OrderedDictionary new at: 'schema' put: 'klibgen.session-completion/1'; at: 'sessionId' put: session id; at: 'state' put: state; at: 'ok' put: true; at: 'sourceChangeCount' put: session sourceChanges changeCount; yourself)) to: path.
	^ self
]
