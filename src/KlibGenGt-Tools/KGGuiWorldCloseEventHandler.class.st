"
Close-request policy for the managed GUI world.

- Slots
  - none
- Public API
  - {{gtMethod:KGGuiWorldCloseEventHandler>>#eventsToHandle}}
    Subscribe to Bloc space-close requests from native and programmatic window closes.
  - {{gtMethod:KGGuiWorldCloseEventHandler>>#spaceCloseRequest:}}
    Preserve a world with restorable tool state and show the save, discard, or cancel prompt.
"
Class {
	#name : 'KGGuiWorldCloseEventHandler',
	#superclass : 'BlCustomEventHandler',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'api - accessing' }
KGGuiWorldCloseEventHandler >> eventsToHandle [
	<return: #(Array<Class>)>
	^ { BlSpaceCloseRequest }
]

{ #category : 'api - event managing' }
KGGuiWorldCloseEventHandler >> spaceCloseRequest: event [
	<arg: #event type: #BlSpaceCloseRequest>
	<return: #KGGuiWorldCloseEventHandler>
	KGSession current persistence available ifFalse: [ ^ self ].
	event shouldClose: false.
	KGGuiSessionHooks requestQuitIn: event currentTarget.
	^ self
]
