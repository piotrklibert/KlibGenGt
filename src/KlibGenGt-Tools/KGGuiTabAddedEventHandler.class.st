"
Marks a GUI run as changed when a tool tab is added.

- Slots
  - none
- Public API
  - {{gtMethod:KGGuiTabAddedEventHandler>>#wantsEvent:}}
    Accept only tab-added events from the managed world's tab-group model.
  - {{gtMethod:KGGuiTabAddedEventHandler>>#handleEvent:}}
    Record that the run now contains restorable image state.
"
Class {
	#name : 'KGGuiTabAddedEventHandler',
	#superclass : 'BlBasicEventHandler',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'api - event managing' }
KGGuiTabAddedEventHandler >> handleEvent: event [
	<arg: #event type: #BrTabAddedEvent>
	<return: #KGGuiTabAddedEventHandler>
	KGGuiSessionHooks noteRestorableState.
	^ self
]

{ #category : 'api - event managing' }
KGGuiTabAddedEventHandler >> wantsEvent: event [
	<arg: #event type: #BlEvent>
	<return: #Boolean>
	^ event class = BrTabAddedEvent
]
