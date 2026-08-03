"
Generated from klibgen_build.json_models; DO NOT EDIT.

Immutable JSON record generated from `SessionV1`.

- Slots
  - `schemaValue` (`#String`, `accessing`) - Value of JSON field `schema`.
  - `schemaVersion` (`#Integer`, `accessing`) - Value of JSON field `schemaVersion`.
  - `sessionId` (`#String`, `accessing`) - Value of JSON field `sessionId`.
  - `projectKey` (`#String`, `accessing`) - Value of JSON field `projectKey`.
  - `recipe` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `recipe`.
  - `preset` (`#KGJsonLaunchPresetRecord`, `accessing`) - Value of JSON field `preset`.
  - `paths` (`#KGJsonSessionPathsRecord`, `accessing`) - Value of JSON field `paths`.
  - `inputs` (`#(Dictionary<String, Any>)`, `accessing`) - Value of JSON field `inputs`.
  - `pid` (`#(Integer | UndefinedObject)`, `accessing`) - Value of JSON field `pid`.
  - `path` (`#(String | UndefinedObject)`, `accessing`) - Value of JSON field `path`.
  - `storage` (`#(KGJsonStorageRecord | UndefinedObject)`, `accessing`) - Value of JSON field `storage`.
- Public API
  - {{gtMethod:KGSessionV1>>#schemaValue}}
    Answer the immutable `schemaValue` field value.
  - {{gtMethod:KGSessionV1>>#schemaVersion}}
    Answer the immutable `schemaVersion` field value.
  - {{gtMethod:KGSessionV1>>#sessionId}}
    Answer the immutable `sessionId` field value.
  - {{gtMethod:KGSessionV1>>#projectKey}}
    Answer the immutable `projectKey` field value.
  - {{gtMethod:KGSessionV1>>#recipe}}
    Answer the immutable `recipe` field value.
  - {{gtMethod:KGSessionV1>>#preset}}
    Answer the immutable `preset` field value.
  - {{gtMethod:KGSessionV1>>#paths}}
    Answer the immutable `paths` field value.
  - {{gtMethod:KGSessionV1>>#inputs}}
    Answer the immutable `inputs` field value.
  - {{gtMethod:KGSessionV1>>#pid}}
    Answer the immutable `pid` field value.
  - {{gtMethod:KGSessionV1>>#path}}
    Answer the immutable `path` field value.
  - {{gtMethod:KGSessionV1>>#storage}}
    Answer the immutable `storage` field value.
"
Class {
	#name : 'KGSessionV1',
	#superclass : 'KGJsonRecord',
	#instVars : [
		'schemaValue',
		'schemaVersion',
		'sessionId',
		'projectKey',
		'recipe',
		'preset',
		'paths',
		'inputs',
		'pid',
		'path',
		'storage'
	],
	#category : 'KlibGenGt-JsonModels',
	#package : 'KlibGenGt-JsonModels'
}

{ #category : 'json schema' }
KGSessionV1 class >> jsonAllowsExtras [
	<return: #Boolean>
	^ true
]

{ #category : 'json schema' }
KGSessionV1 class >> jsonFieldSpecifications [
	<return: #(Array<(Array<Any>)>)>
	^ {
		#('schema' 'schemaValue' true #(#literal #('klibgen.session/1'))).
		#('schemaVersion' 'schemaVersion' true #(#literal #(1))).
		#('sessionId' 'sessionId' true #(#string)).
		#('projectKey' 'projectKey' true #(#string)).
		#('recipe' 'recipe' false #(#union #(#(#string) #(#nil)))).
		#('preset' 'preset' true #(#model #KGJsonLaunchPresetRecord)).
		#('paths' 'paths' true #(#model #KGJsonSessionPathsRecord)).
		#('inputs' 'inputs' false #(#dictionary #(#any))).
		#('pid' 'pid' false #(#union #(#(#integer) #(#nil)))).
		#('path' 'path' false #(#union #(#(#string) #(#nil)))).
		#('storage' 'storage' false #(#union #(#(#model #KGJsonStorageRecord) #(#nil)))) }
]

{ #category : 'json schema' }
KGSessionV1 class >> jsonSchemaName [
	<return: #(String?)>
	^ 'klibgen.session/1'
]

{ #category : 'accessing' }
KGSessionV1 >> inputs [
	<return: #(Dictionary<String, Any>)>
	^ self defensiveJsonValue: inputs
]

{ #category : 'accessing' }
KGSessionV1 >> path [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: path
]

{ #category : 'accessing' }
KGSessionV1 >> paths [
	<return: #KGJsonSessionPathsRecord>
	^ self defensiveJsonValue: paths
]

{ #category : 'accessing' }
KGSessionV1 >> pid [
	<return: #(Integer | UndefinedObject)>
	^ self defensiveJsonValue: pid
]

{ #category : 'accessing' }
KGSessionV1 >> preset [
	<return: #KGJsonLaunchPresetRecord>
	^ self defensiveJsonValue: preset
]

{ #category : 'accessing' }
KGSessionV1 >> projectKey [
	<return: #String>
	^ self defensiveJsonValue: projectKey
]

{ #category : 'accessing' }
KGSessionV1 >> recipe [
	<return: #(String | UndefinedObject)>
	^ self defensiveJsonValue: recipe
]

{ #category : 'accessing' }
KGSessionV1 >> schemaValue [
	<return: #String>
	^ self defensiveJsonValue: schemaValue
]

{ #category : 'accessing' }
KGSessionV1 >> schemaVersion [
	<return: #Integer>
	^ self defensiveJsonValue: schemaVersion
]

{ #category : 'accessing' }
KGSessionV1 >> sessionId [
	<return: #String>
	^ self defensiveJsonValue: sessionId
]

{ #category : 'accessing' }
KGSessionV1 >> storage [
	<return: #(KGJsonStorageRecord | UndefinedObject)>
	^ self defensiveJsonValue: storage
]
