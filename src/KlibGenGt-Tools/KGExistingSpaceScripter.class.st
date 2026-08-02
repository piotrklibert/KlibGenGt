"Attach Bloc Scripter actions to an already-open space without moving its root element.

- Slots
  - none; inherited `BlScripter` state is rebound by {{gtMethod:KGExistingSpaceScripter>>#attachToSpace:}}.
- Public API
  - {{gtMethod:KGExistingSpaceScripter>>#attachToSpace:}}
    Replace the disposable Scripter space with an existing space while preserving its hierarchy.
  - {{gtMethod:KGExistingSpaceScripter>>#act:on:request:}}
    Dispatch one named Scripter action without pulsing, for use inside the live UI task queue.
  - {{gtMethod:KGExistingSpaceScripter>>#detach}}
    Remove event collection filters from the existing space without changing its elements.
"
Class {
	#name : 'KGExistingSpaceScripter',
	#superclass : 'BlScripter',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'public - attaching' }
KGExistingSpaceScripter >> attachToSpace: aSpace [
	<arg: #aSpace type: #BlSpace>
	<return: #KGExistingSpaceScripter>
	space removeEventFilter: eventHandler.
	space root removeEventFilter: eventHandler.
	space := aSpace.
	element := aSpace root.
	space addEventFilter: eventHandler.
	space root addEventFilter: eventHandler.
	^ self
]

{ #category : 'public - actions' }
KGExistingSpaceScripter >> act: actionName on: target request: aRequest [
	<arg: #actionName type: #String>
	<arg: #target type: #BlElement>
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #KGExistingSpaceScripter>
	| point position key modifiers combination buffer event delta |
	position := target bounds inSpace center.
	modifiers := BlKeyModifiers new.
	actionName = 'click' ifTrue: [
		BlEvent fireEvent: (BlMouseUpEvent primary position: position) asClickEvent target: target ].
	actionName = 'double-click' ifTrue: [
		BlEvent fireEvent: (BlMouseUpEvent primary position: position) asDoubleClickEvent target: target ].
	actionName = 'secondary-click' ifTrue: [
		BlEvent fireEvent: (BlMouseUpEvent secondary position: position) asClickEvent target: target ].
	actionName = 'hover' ifTrue: [ self dispatch: { BlMouseMoveEvent new position: position } on: target ].
	actionName = 'focus' ifTrue: [ target requestFocus ].
	actionName = 'type' ifTrue: [
		event := BlTextInputEvent new text: (aRequest at: 'value').
		self dispatch: { event } on: target ].
	actionName = 'key-press' ifTrue: [
		key := BlKeyboardKey perform: (aRequest at: 'key') asSymbol.
		self dispatch: {
			BlKeyDownEvent new key: key; modifiers: modifiers; scanCode: key valueOrZero.
			BlKeyUpEvent new key: key; modifiers: modifiers; scanCode: key valueOrZero } on: target ].
	actionName = 'shortcut' ifTrue: [
		combination := BlKeyCombination perform: (aRequest at: 'value') asSymbol.
		buffer := BlKeyboardBuffer new.
		combination asBufferKeys do: [ :each | buffer add: (BlKeyDownEvent new key: each) ].
		BlEvent fireEvent: (BlShortcutEvent new buffer: buffer) target: target ].
	point := (aRequest at: 'dx' ifAbsent: [ 0 ]) @ (aRequest at: 'dy' ifAbsent: [ 0 ]).
	actionName = 'scroll' ifTrue: [
		self dispatch: { BlMouseWheelEvent new isTouch: false; vector: point asBlocVector; position: position } on: target ].
	actionName = 'drag' ifTrue: [
		delta := (target localBoundsToGlobal: (BlBounds origin: 0 @ 0 extent: point)) extent.
		self dispatch: {
			BlMouseDownEvent primary position: position.
			BlMouseMoveEvent primary position: position + delta.
			BlMouseUpEvent primary position: position + delta } on: target ].
	(#('click' 'double-click' 'secondary-click' 'hover' 'focus' 'type' 'key-press' 'shortcut' 'scroll' 'drag')
		includes: actionName) ifFalse: [ self error: 'unsupported UI action: ' , actionName ].
	^ self
]

{ #category : 'private - actions' }
KGExistingSpaceScripter >> dispatch: events on: target [
	events do: [ :event | event timestamp: DateAndTime now ].
	events do: [ :event | space dispatchEvent: event ].
	space dispatchEvent: BlSpaceEventsProcessedEvent new.
	space requestNextPulse
]

{ #category : 'public - attaching' }
KGExistingSpaceScripter >> detach [
	<return: #KGExistingSpaceScripter>
	space removeEventFilter: eventHandler.
	space root removeEventFilter: eventHandler.
	^ self
]
