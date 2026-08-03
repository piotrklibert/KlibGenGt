Extension { #name : 'GtWorldElement' }

{ #category : '*KlibGenGt-Tools' }
GtWorldElement >> kgExportActionFor: anAction [
	<gtWorldAction>
	<arg: #anAction type: #GtPhlowAction>
	<return: #GtPhlowAction>
	^ anAction explicit
		priority: 45;
		stencil: [ KGExportButton new ]
]

{ #category : '*KlibGenGt-Tools' }
GtWorldElement >> kgPromoteActionFor: anAction [
	<gtWorldAction>
	<arg: #anAction type: #GtPhlowAction>
	<return: #GtPhlowAction>
	^ anAction explicit
		priority: 46;
		stencil: [ KGPromoteButton new ]
]
