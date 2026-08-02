"Abstract transport for schema-version-one live UI control envelopes.

- Slots
  - `service` (`#KGUiControlService`, `requests`) - Connector-independent request handler.
- Public API
  - {{gtMethod:KGUiControlConnector>>#service:}}
    Attach the service that validates and executes received request envelopes.
  - {{gtMethod:KGUiControlConnector>>#start}}
    Start accepting requests; subclasses define the transport.
  - {{gtMethod:KGUiControlConnector>>#stop}}
    Stop accepting requests and release transport resources idempotently.
"
Class { #name : 'KGUiControlConnector', #superclass : 'Object', #instVars : [ 'service' ], #category : 'KlibGenGt-Tools', #package : 'KlibGenGt-Tools' }

{ #category : 'accessing' }
KGUiControlConnector >> service: aService [
	<arg: #aService type: #KGUiControlService> <return: #KGUiControlConnector>
	service := aService. ^ self
]

{ #category : 'public - lifecycle' }
KGUiControlConnector >> start [ <return: #KGUiControlConnector> self subclassResponsibility ]

{ #category : 'public - lifecycle' }
KGUiControlConnector >> stop [ <return: #KGUiControlConnector> self subclassResponsibility ]
