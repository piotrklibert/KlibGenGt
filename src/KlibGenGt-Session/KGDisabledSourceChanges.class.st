"
Deny every project-source mutation in read-only sessions.

- Slots
  - none
- Public API
  - {{gtMethod:KGDisabledSourceChanges>>#available}}
    Answer false so controls can reflect capability availability.
  - {{gtMethod:KGDisabledSourceChanges>>#changeCount}}
    Answer zero without consulting an export repository.
  - {{gtMethod:KGDisabledSourceChanges>>#exportChanges}}
    Reject source mutation at the enforcement point.
  - {{gtMethod:KGDisabledSourceChanges>>#promoteChanges}}
    Reject staging promotion in a read-only session.
"
Class {
	#name : 'KGDisabledSourceChanges',
	#superclass : 'Object',
	#category : 'KlibGenGt-Session',
	#package : 'KlibGenGt-Session'
}

{ #category : 'testing' }
KGDisabledSourceChanges >> available [ <return: #Boolean> ^ false
]

{ #category : 'accessing' }
KGDisabledSourceChanges >> changeCount [ <return: #Integer> ^ 0
]

{ #category : 'actions' }
KGDisabledSourceChanges >> exportChanges [
	<return: #Nothing>
	self error: 'Source changes are disabled for this session'
]

{ #category : 'actions' }
KGDisabledSourceChanges >> promoteChanges [
	<return: #Nothing>
	self error: 'Source changes are disabled for this session'
]
