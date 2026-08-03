"
Deny image persistence and record discard as the only orderly policy.

- Slots
  - none
- Public API
  - {{gtMethod:KGDiscardPersistence>>#available}}
    Answer false because saving is unavailable.
  - {{gtMethod:KGDiscardPersistence>>#save}}
    Reject image persistence.
  - {{gtMethod:KGDiscardPersistence>>#discard}}
    Answer the authoritative discarded outcome name.
"
Class {
	#name : 'KGDiscardPersistence',
	#superclass : 'Object',
	#category : 'KlibGenGt-Session',
	#package : 'KlibGenGt-Session'
}

{ #category : 'testing' }
KGDiscardPersistence >> available [ <return: #Boolean> ^ false
]

{ #category : 'actions' }
KGDiscardPersistence >> discard [ <return: #String> ^ 'discarded'
]

{ #category : 'actions' }
KGDiscardPersistence >> save [ <return: #Nothing> self error: 'Image persistence is disabled for this session'
]
