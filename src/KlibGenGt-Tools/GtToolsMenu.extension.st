Extension { #name : 'GtToolsMenu' }

{ #category : '*KlibGenGt-Tools' }
GtToolsMenu >> quitFrom: button [
	<arg: #button type: #BrButton>
	<return: #GtToolsMenu>
	KGGuiSessionHooks requestQuitFrom: button.
	^ self
]
