"Commit the live image's project changes to the managed GUI export repository.

- Public API
  - {{gtMethod:KGExportTool>>#changeCount}}
    Answer the number of modified KlibGenGt packages in Iceberg.
  - {{gtMethod:KGExportTool>>#commitTitle}}
    Answer the synthetic title for the current export commit.
  - {{gtMethod:KGExportTool>>#exportChanges}}
    Commit every pending repository change and announce the Iceberg commit.
"
Class {
	#name : 'KGExportTool',
	#superclass : 'Object',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'public - accessing' }
KGExportTool >> changeCount [
	<return: #Integer>
	^ KGSession current sourceChanges changeCount
]

{ #category : 'public - accessing' }
KGExportTool >> commitTitle [
	<return: #String>
	^ 'Export KlibGenGt changes (' , self changeCount printString , ')'
]

{ #category : 'public - actions' }
KGExportTool >> exportChanges [
	<return: #(IceCommit?)>
	^ KGSession current sourceChanges exportChanges
]
