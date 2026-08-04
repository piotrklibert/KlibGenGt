| sqliteRepository neoJSONRepository jsonSchemaRepository |
sqliteRepository := Smalltalk os environment at: 'KLIBGEN_SQLITE_REPOSITORY'.
neoJSONRepository := Smalltalk os environment at: 'KLIBGEN_NEOJSON_REPOSITORY'.
jsonSchemaRepository := Smalltalk os environment at: 'KLIBGEN_JSONSCHEMA_REPOSITORY'.
Metacello new baseline: 'SQLite3'; repository: sqliteRepository; onConflictUseIncoming; load: 'Core'.
Metacello new baseline: 'NeoJSON'; repository: neoJSONRepository; onConflictUseIncoming; load: 'core'.
Metacello new baseline: 'JSONSchema'; repository: jsonSchemaRepository; onConflictUseLoaded; load: 'Core'.
Stdio stdout nextPutAll: 'Loaded pinned SQLite3, NeoJSON, and JSONSchema dependencies'; lf; flush.
Smalltalk snapshot: true andQuit: true
