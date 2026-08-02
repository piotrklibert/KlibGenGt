"Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `WorkspaceV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `name` (`#String`, `accessing`) - Value of JSON field `name`.
  - `state` (`#String`, `accessing`) - Value of JSON field `state`.
  - `projectKey` (`#String`, `accessing`) - Value of JSON field `projectKey`.
  - `artifactPath` (`#String`, `accessing`) - Value of JSON field `artifactPath`.
  - `baseSource` (`#(Dictionary<String, Any>)`, `accessing`) - Value of JSON field `baseSource`.
  - `sourceGit` (`#String`, `accessing`) - Value of JSON field `sourceGit`.
  - `lastCompletion` (`#(KGSessionCompletionV1 | UndefinedObject)`, `accessing`) - Value of JSON field `lastCompletion`.
  - `pid` (`#(Integer | UndefinedObject)`, `accessing`) - Value of JSON field `pid`.
  - `sessionId` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `sessionId`.
  - `path` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `path`.
  - `storage` (`#(KGJsonStorageRecord | UndefinedObject)`, `accessing`) - Value of JSON field `storage`.
- Public API
  - {{gtMethod:KGWorkspaceV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGWorkspaceV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGWorkspaceV1>>#name}}
    Answer the immutable `name` field value.
  - {{gtMethod:KGWorkspaceV1>>#state}}
    Answer the immutable `state` field value.
  - {{gtMethod:KGWorkspaceV1>>#projectKey}}
    Answer the immutable `projectKey` field value.
  - {{gtMethod:KGWorkspaceV1>>#artifactPath}}
    Answer the immutable `artifactPath` field value.
  - {{gtMethod:KGWorkspaceV1>>#baseSource}}
    Answer the immutable `baseSource` field value.
  - {{gtMethod:KGWorkspaceV1>>#sourceGit}}
    Answer the immutable `sourceGit` field value.
  - {{gtMethod:KGWorkspaceV1>>#lastCompletion}}
    Answer the immutable `lastCompletion` field value.
  - {{gtMethod:KGWorkspaceV1>>#pid}}
    Answer the immutable `pid` field value.
  - {{gtMethod:KGWorkspaceV1>>#sessionId}}
    Answer the immutable `sessionId` field value.
  - {{gtMethod:KGWorkspaceV1>>#path}}
    Answer the immutable `path` field value.
  - {{gtMethod:KGWorkspaceV1>>#storage}}
    Answer the immutable `storage` field value."
Class {
	#name : 'KGWorkspaceV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'name',
		'state',
		'projectKey',
		'artifactPath',
		'baseSource',
		'sourceGit',
		'lastCompletion',
		'pid',
		'sessionId',
		'path',
		'storage'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGWorkspaceV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ true
]

{ #category : 'json schema' }
KGWorkspaceV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.workspace/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('name' 'name' true #(#string)).
		#('state' 'state' true #(#literal #('ready' 'active' 'saved'))).
		#('projectKey' 'projectKey' true #(#string)).
		#('artifactPath' 'artifactPath' true #(#string)).
		#('baseSource' 'baseSource' true #(#dictionary #(#any))).
		#('sourceGit' 'sourceGit' true #(#string)).
		#('lastCompletion' 'lastCompletion' true #(#union #(#(#model #KGSessionCompletionV1) #(#nil)))).
		#('pid' 'pid' false #(#union #(#(#integer) #(#nil)))).
		#('sessionId' 'sessionId' false #(#union #(#(#string) #(#nil)))).
		#('path' 'path' false #(#union #(#(#string) #(#nil)))).
		#('storage' 'storage' false #(#union #(#(#model #KGJsonStorageRecord) #(#nil)))) }
]

{ #category : 'json schema' }
KGWorkspaceV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.workspace/1'
]

{ #category : 'accessing' }
KGWorkspaceV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGWorkspaceV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGWorkspaceV1 >> name [
	<return: #String>
	^ self defensiveJsonValue: name
]

{ #category : 'accessing' }
KGWorkspaceV1 >> state [
	<return: #String>
	^ self defensiveJsonValue: state
]

{ #category : 'accessing' }
KGWorkspaceV1 >> projectKey [
	<return: #String>
	^ self defensiveJsonValue: projectKey
]

{ #category : 'accessing' }
KGWorkspaceV1 >> artifactPath [
	<return: #String>
	^ self defensiveJsonValue: artifactPath
]

{ #category : 'accessing' }
KGWorkspaceV1 >> baseSource [
	<return: #(Dictionary<String, Any>)>
	^ self defensiveJsonValue: baseSource
]

{ #category : 'accessing' }
KGWorkspaceV1 >> sourceGit [
	<return: #String>
	^ self defensiveJsonValue: sourceGit
]

{ #category : 'accessing' }
KGWorkspaceV1 >> lastCompletion [
	<return: #(KGSessionCompletionV1 | UndefinedObject)>
	^ self defensiveJsonValue: lastCompletion
]

{ #category : 'accessing' }
KGWorkspaceV1 >> pid [
	<return: #(Integer | UndefinedObject)>
	^ self defensiveJsonValue: pid
]

{ #category : 'accessing' }
KGWorkspaceV1 >> sessionId [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: sessionId
]

{ #category : 'accessing' }
KGWorkspaceV1 >> path [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: path
]

{ #category : 'accessing' }
KGWorkspaceV1 >> storage [
	<return: #(KGJsonStorageRecord | UndefinedObject)>
	^ self defensiveJsonValue: storage
]
