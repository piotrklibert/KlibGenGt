"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `StagingV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `name` (`#String`, `accessing`) - Value of JSON field `name`.
  - `state` (`#String`, `accessing`) - Value of JSON field `state`.
  - `baseSource` (`#(Dictionary<String, Any>)`, `accessing`) - Value of JSON field `baseSource`.
  - `projectKey` (`#String`, `accessing`) - Value of JSON field `projectKey`.
  - `sourceGit` (`#String`, `accessing`) - Value of JSON field `sourceGit`.
  - `promotion` (`#(KGJsonPromotionRecord | UndefinedObject)`, `accessing`) - Value of JSON field `promotion`.
  - `generation` (`#(Integer | UndefinedObject)`, `accessing`) - Value of JSON field `generation`.
  - `headCommit` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `headCommit`.
  - `lease` (`#((Dictionary<String, Any>) | UndefinedObject)`, `accessing`) - Value of JSON field `lease`.
  - `lastRebase` (`#((Dictionary<String, Any>) | UndefinedObject)`, `accessing`) - Value of JSON field `lastRebase`.
  - `lastPromotion` (`#((Dictionary<String, Any>) | UndefinedObject)`, `accessing`) - Value of JSON field `lastPromotion`.
  - `path` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `path`.
  - `changes` (`#(KGJsonStagingChangesRecord | UndefinedObject)`, `accessing`) - Value of JSON field `changes`.
  - `storage` (`#(KGJsonStorageRecord | UndefinedObject)`, `accessing`) - Value of JSON field `storage`.
- Public API
  - {{gtMethod:KGStagingV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGStagingV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGStagingV1>>#name}}
    Answer the immutable `name` field value.
  - {{gtMethod:KGStagingV1>>#state}}
    Answer the immutable `state` field value.
  - {{gtMethod:KGStagingV1>>#baseSource}}
    Answer the immutable `baseSource` field value.
  - {{gtMethod:KGStagingV1>>#projectKey}}
    Answer the immutable `projectKey` field value.
  - {{gtMethod:KGStagingV1>>#sourceGit}}
    Answer the immutable `sourceGit` field value.
  - {{gtMethod:KGStagingV1>>#promotion}}
    Answer the immutable `promotion` field value.
  - {{gtMethod:KGStagingV1>>#generation}}
    Answer the immutable `generation` field value.
  - {{gtMethod:KGStagingV1>>#headCommit}}
    Answer the immutable `headCommit` field value.
  - {{gtMethod:KGStagingV1>>#lease}}
    Answer the immutable `lease` field value.
  - {{gtMethod:KGStagingV1>>#lastRebase}}
    Answer the immutable `lastRebase` field value.
  - {{gtMethod:KGStagingV1>>#lastPromotion}}
    Answer the immutable `lastPromotion` field value.
  - {{gtMethod:KGStagingV1>>#path}}
    Answer the immutable `path` field value.
  - {{gtMethod:KGStagingV1>>#changes}}
    Answer the immutable `changes` field value.
  - {{gtMethod:KGStagingV1>>#storage}}
    Answer the immutable `storage` field value."
Class {
	#name : 'KGStagingV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'name',
		'state',
		'baseSource',
		'projectKey',
		'sourceGit',
		'promotion',
		'generation',
		'headCommit',
		'lease',
		'lastRebase',
		'lastPromotion',
		'path',
		'changes',
		'storage'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGStagingV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ true
]

{ #category : 'json schema' }
KGStagingV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.staging/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('name' 'name' true #(#string)).
		#('state' 'state' true #(#literal #('ready' 'conflicted' 'promoted'))).
		#('baseSource' 'baseSource' true #(#dictionary #(#any))).
		#('projectKey' 'projectKey' true #(#string)).
		#('sourceGit' 'sourceGit' true #(#string)).
		#('promotion' 'promotion' true #(#union #(#(#model #KGJsonPromotionRecord) #(#nil)))).
		#('generation' 'generation' false #(#constrained #(#union #(#(#integer) #(#nil))) #(#(#ge 1)))).
		#('headCommit' 'headCommit' false #(#union #(#(#string) #(#nil)))).
		#('lease' 'lease' false #(#union #(#(#dictionary #(#any)) #(#nil)))).
		#('lastRebase' 'lastRebase' false #(#union #(#(#dictionary #(#any)) #(#nil)))).
		#('lastPromotion' 'lastPromotion' false #(#union #(#(#dictionary #(#any)) #(#nil)))).
		#('path' 'path' false #(#union #(#(#string) #(#nil)))).
		#('changes' 'changes' false #(#union #(#(#model #KGJsonStagingChangesRecord) #(#nil)))).
		#('storage' 'storage' false #(#union #(#(#model #KGJsonStorageRecord) #(#nil)))) }
]

{ #category : 'json schema' }
KGStagingV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.staging/1'
]

{ #category : 'accessing' }
KGStagingV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGStagingV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGStagingV1 >> name [
	<return: #String>
	^ self defensiveJsonValue: name
]

{ #category : 'accessing' }
KGStagingV1 >> state [
	<return: #String>
	^ self defensiveJsonValue: state
]

{ #category : 'accessing' }
KGStagingV1 >> baseSource [
	<return: #(Dictionary<String, Any>)>
	^ self defensiveJsonValue: baseSource
]

{ #category : 'accessing' }
KGStagingV1 >> projectKey [
	<return: #String>
	^ self defensiveJsonValue: projectKey
]

{ #category : 'accessing' }
KGStagingV1 >> sourceGit [
	<return: #String>
	^ self defensiveJsonValue: sourceGit
]

{ #category : 'accessing' }
KGStagingV1 >> promotion [
	<return: #(KGJsonPromotionRecord | UndefinedObject)>
	^ self defensiveJsonValue: promotion
]

{ #category : 'accessing' }
KGStagingV1 >> generation [
	<return: #(Integer | UndefinedObject)>
	^ self defensiveJsonValue: generation
]

{ #category : 'accessing' }
KGStagingV1 >> headCommit [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: headCommit
]

{ #category : 'accessing' }
KGStagingV1 >> lease [
	<return: #((Dictionary<String, Any>) | UndefinedObject)>
	^ self defensiveJsonValue: lease
]

{ #category : 'accessing' }
KGStagingV1 >> lastRebase [
	<return: #((Dictionary<String, Any>) | UndefinedObject)>
	^ self defensiveJsonValue: lastRebase
]

{ #category : 'accessing' }
KGStagingV1 >> lastPromotion [
	<return: #((Dictionary<String, Any>) | UndefinedObject)>
	^ self defensiveJsonValue: lastPromotion
]

{ #category : 'accessing' }
KGStagingV1 >> path [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: path
]

{ #category : 'accessing' }
KGStagingV1 >> changes [
	<return: #(KGJsonStagingChangesRecord | UndefinedObject)>
	^ self defensiveJsonValue: changes
]

{ #category : 'accessing' }
KGStagingV1 >> storage [
	<return: #(KGJsonStorageRecord | UndefinedObject)>
	^ self defensiveJsonValue: storage
]
