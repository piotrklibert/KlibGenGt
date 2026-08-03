# Working with JSON, JSON Schema, and Model Classes in Pharo/GToolkit

**Libraries:** [NeoJSON](https://github.com/svenvc/NeoJSON) and [ApptiveGrid/JSONSchema](https://github.com/ApptiveGrid/JSONSchema)  
**Audience:** Pharo/GToolkit developers consuming and producing external JSON  
**Verified:** 2026-08-03, against NeoJSON commit [`11e274d`](https://github.com/svenvc/NeoJSON/commit/11e274dd96dc9636cab90929937b7cd09719de7c) and JSONSchema commit [`d6ac78c`](https://github.com/ApptiveGrid/JSONSchema/commit/d6ac78c12ad66d582adc88d5f2c4f5ee6b0d78a7)

> The examples use the Pharo 12+ fluid class-definition syntax. The same classes
> can be defined with the older `subclass:instanceVariableNames:...` syntax.

## 1. The division of responsibilities

The two libraries overlap, but they solve different primary problems.

**NeoJSON** provides:

- JSON parsing and writing;
- streaming readers and writers;
- generic JSON values represented as `Dictionary`, `Array`, strings, numbers, booleans, and `nil`;
- mappings between JSON objects and ordinary Smalltalk objects;
- custom encoders and decoders;
- typed lists and nested object mappings.

**JSONSchema** provides:

- JSON Schema parsing and serialization;
- a Smalltalk DSL for building schemas;
- structural validation;
- constraints such as ranges, patterns, formats, enumerations, required fields, and composition;
- conversion of formatted JSON strings to Smalltalk values such as `DateAndTime`;
- schema-directed reading and writing;
- optional creation of a chosen model class through `JSONSchemaObject>>instanceClass:`.

A practical architecture normally uses them as follows:

```text
external bytes
    |
    v
NeoJSON parser
    |
    v
JSON-shaped Smalltalk graph
(Dictionary / Array / primitives)
    |
    +--> normalization or migration
    |
    v
JSONSchema validation
    |
    v
schema-directed materialization
    |
    v
domain/model objects
```

For the simplest strict case, JSONSchema can combine parsing, validation, conversion, and materialization in one pass:

```smalltalk
model := schema readFrom: aCharacterStream
```

For tolerant ingestion, migrations, diagnostics, and correction, it is usually better to split the phases explicitly.

## 2. Installation and reproducible dependencies

NeoJSON can be loaded independently:

```smalltalk
Metacello new
    repository: 'github://svenvc/NeoJSON/repository';
    baseline: 'NeoJSON';
    load
```

JSONSchema declares NeoJSON as its only external dependency:

```smalltalk
Metacello new
    repository: 'github://ApptiveGrid/JSONSchema';
    baseline: 'JSONSchema';
    load
```

In a project baseline:

```smalltalk
BaselineOfKlibGen >> baseline: spec
    <baseline>

    spec
        for: #common
        do: [
            spec
                baseline: 'NeoJSON'
                with: [
                    spec repository:
                        'github://svenvc/NeoJSON/repository' ].

            spec
                baseline: 'JSONSchema'
                with: [
                    spec repository:
                        'github://ApptiveGrid/JSONSchema' ].

            spec
                package: 'KlibGen-JSON'
                with: [
                    spec requires: #('NeoJSON' 'JSONSchema') ] ]
```

For reproducible images, pin tags or commit hashes rather than following
`master` indefinitely. JSONSchema was receiving active fixes at the time this
guide was written, and its repository explicitly documents incomplete coverage
of the full JSON Schema specification. Maintain project-level tests for every
keyword and format on which the application depends.

## 3. Running example

The examples use a build-inventory document:

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-08-03T20:00:00+02:00",
  "project": {
    "name": "KlibGenGt",
    "repository": "https://github.com/example/KlibGenGt"
  },
  "artifacts": [
    {
      "path": "lib/libgit2.so",
      "kind": "shared-library",
      "size": 1827360,
      "tags": ["native", "linux"]
    }
  ],
  "metadata": {
    "producer": "klibgen",
    "host": "builder-01"
  }
}
```

The corresponding model consists of three classes.

```smalltalk
Object << #KgJsonModel
    package: 'KlibGen-JSON-Model'.

KgJsonModel << #KgBuildProject
    slots: { #name. #repository };
    package: 'KlibGen-JSON-Model'.

KgJsonModel << #KgBuildArtifact
    slots: { #path. #kind. #size. #tags };
    package: 'KlibGen-JSON-Model'.

KgJsonModel << #KgBuildInventory
    slots: {
        #schemaVersion.
        #generatedAt.
        #project.
        #artifacts.
        #metadata };
    package: 'KlibGen-JSON-Model'
```

Generate ordinary accessors in Coder, or implement them manually:

```smalltalk
KgBuildArtifact >> path
    ^ path

KgBuildArtifact >> path: aString
    path := aString
```

The same pattern applies to the remaining slots.

### 3.1 A strict JSON-model base class

JSONSchema adds a generic protocol to `Object`:

- `jsonSchemaAt:`
- `jsonSchemaAt:put:`
- `jsonSchemaKeys`

Its default setter silently does nothing when the corresponding setter is
absent. For external models, silently dropping a validated property is
dangerous. Override the protocol in a common superclass:

```smalltalk
KgJsonModel >> jsonSchemaAt: aProperty
    | selector |

    selector := aProperty asSymbol.
    (self respondsTo: selector)
        ifFalse: [
            KgJsonModelMappingError signal:
                'No getter for JSON property ',
                aProperty printString,
                ' on ',
                self class name ].

    ^ self perform: selector
```

```smalltalk
KgJsonModel >> jsonSchemaAt: aProperty put: aValue
    | selector |

    selector := aProperty asSymbol asMutator.
    (self respondsTo: selector)
        ifFalse: [
            KgJsonModelMappingError signal:
                'No setter for JSON property ',
                aProperty printString,
                ' on ',
                self class name ].

    ^ self perform: selector with: aValue
```

```smalltalk
KgJsonModel >> jsonSchemaKeys
    ^ self class allInstVarNames
```

Define the domain-specific exception:

```smalltalk
Error << #KgJsonModelMappingError
    package: 'KlibGen-JSON-Errors'
```

This turns mismatches between schema properties and model accessors into explicit failures.

An alternative is to implement `jsonSchemaAt:` and `jsonSchemaAt:put:` with `instVarNamed:` and `instVarNamed:put:`. Accessor-based mapping is usually preferable because it preserves encapsulation and permits normalization or invariants in setters.

## 4. NeoJSON mappings for model classes

JSONSchema-directed materialization does not require NeoJSON mappings for the model classes: setters plus `instanceClass:` are enough. NeoJSON mappings are still useful for:

- direct serialization without a JSONSchema writer;
- direct NeoJSON deserialization;
- integration with APIs already using NeoJSON;
- generating a generic JSON representation from a model;
- handling aliases and custom conversions independently of JSONSchema.

### 4.1 Simple object mappings

```smalltalk
KgBuildProject class >> neoJsonMapping: mapper
    mapper
        for: self
        do: [ :mapping |
            mapping mapAccessors: #(name repository) ]
```

```smalltalk
KgBuildArtifact class >> neoJsonMapping: mapper
    mapper
        for: self
        do: [ :mapping |
            mapping mapAccessors: #(path kind size tags) ]
```

### 4.2 Nested values, typed lists, and custom conversions

```smalltalk
KgBuildInventory class >> neoJsonMapping: mapper
    mapper
        for: self
        do: [ :mapping |
            mapping mapAccessor: #schemaVersion.

            (mapping mapAccessor: #generatedAt)
                valueSchema: DateAndTime.

            (mapping mapAccessor: #project)
                valueSchema: KgBuildProject.

            (mapping mapAccessor: #artifacts)
                valueSchema: #KgBuildArtifactList.

            mapping mapAccessor: #metadata ].

    mapper
        for: #KgBuildArtifactList
        customDo: [ :mapping |
            mapping listOfElementSchema: KgBuildArtifact ].

    mapper
        for: DateAndTime
        customDo: [ :mapping |
            mapping
                decoder: [ :string |
                    DateAndTime fromString: string ];
                encoder: [ :dateAndTime |
                    dateAndTime printString ] ]
```

For an interoperable protocol, use an explicitly defined ISO-8601 formatter rather than assuming that a general `printString` will remain the canonical wire representation.

### 4.3 Reading directly through NeoJSON

```smalltalk
inventory := (
    NeoJSONReader
        on: jsonString readStream)
        nextAs: KgBuildInventory
```

The mapping creates the object graph, but NeoJSON alone does not enforce required fields, ranges, allowed values, or unknown-property policy.

### 4.4 Writing directly through NeoJSON

```smalltalk
jsonString := String streamContents: [ :stream |
    (NeoJSONWriter on: stream)
        prettyPrint: true;
        nextPut: inventory ]
```

This follows the NeoJSON mappings. It does not automatically validate the output against the JSON Schema.

## 5. Defining schemas in Smalltalk

### 5.1 Project schema

```smalltalk
KgBuildProject class >> jsonSchema
    | schema |

    schema := {
        'name' -> JSONSchema string.
        'repository' -> JSONSchema string
    } asJSONSchema.

    schema
        required: #('name');
        additionalProperties: false;
        instanceClass: self.

    ^ schema
```

### 5.2 Artifact schema

```smalltalk
KgBuildArtifact class >> jsonSchema
    | schema sizeSchema tagsSchema kindSchema |

    sizeSchema := JSONSchema integer.
    sizeSchema interval minimum: 0.

    tagsSchema := JSONSchemaArray new
        items: JSONSchema string;
        yourself.

    kindSchema := JSONSchema string
        enum: #(
            'shared-library'
            'executable'
            'resource').

    schema := {
        'path' -> JSONSchema string.
        'kind' -> kindSchema.
        'size' -> sizeSchema.
        'tags' -> tagsSchema
    } asJSONSchema.

    schema
        required: #('path' 'kind' 'size');
        additionalProperties: false;
        instanceClass: self.

    ^ schema
```

### 5.3 Root inventory schema

```smalltalk
KgBuildInventory class >> jsonSchema
    | schema artifactListSchema metadataSchema |

    artifactListSchema := JSONSchemaArray new
        items: KgBuildArtifact jsonSchema;
        yourself.

    metadataSchema := JSONSchemaObject new
        additionalProperties: JSONSchema any;
        instanceClass: Dictionary;
        yourself.

    schema := {
        'schemaVersion' -> JSONSchema integer.
        'generatedAt' -> JSONSchema dateAndTime.
        'project' -> KgBuildProject jsonSchema.
        'artifacts' -> artifactListSchema.
        'metadata' -> metadataSchema
    } asJSONSchema.

    schema
        required: #(
            'schemaVersion'
            'generatedAt'
            'project'
            'artifacts');
        additionalProperties: false;
        instanceClass: self.

    ^ schema
```

The nested object schemas each specify their own `instanceClass:`. The array schema then delegates each element to the artifact schema, so a single streaming read creates the entire nested object graph.

### 5.4 When to use a JSON Schema document instead of the DSL

The Smalltalk DSL is convenient for ordinary model schemas. Prefer an external JSON Schema document when:

- another system owns the schema;
- the schema is generated from OpenAPI;
- the schema uses local `$ref`;
- it contains substantial `oneOf`, `anyOf`, `allOf`, or conditional logic;
- it must be shared across languages;
- schema review and versioning should be independent of Smalltalk code.

```smalltalk
schema := JSONSchema fromString: schemaFile contents
```

## 6. Reading JSON files with a known schema

Pharo/GToolkit file references provide character streams and close them after `readStreamDo:` returns.

### 6.1 Strict one-pass read into model classes

```smalltalk
inventoryFile := './build-inventory.json' asFileReference.
schema := KgBuildInventory jsonSchema.

inventory := inventoryFile readStreamDo: [ :stream |
    schema readFrom: stream ]
```

This performs:

1. JSON parsing;
2. schema-directed conversion;
3. validation during reading;
4. nested model construction.

A `date-time` string becomes a `DateAndTime`; nested object schemas create their chosen classes.

### 6.2 Require complete input consumption

`NeoJSONReader>>next` and JSONSchema's convenience reads do not necessarily prove that the stream contains exactly one JSON value. For configuration and interchange files, reject trailing non-whitespace input explicitly:

```smalltalk
inventory := inventoryFile readStreamDo: [ :stream |
    | reader result |

    reader := NeoJSONReader on: stream.
    result := schema readUsing: reader.
    reader failIfNotAtEnd.
    result ]
```

Use the same pattern for generic parsing:

```smalltalk
jsonValue := inventoryFile readStreamDo: [ :stream |
    | reader result |

    reader := NeoJSONReader on: stream.
    result := reader next.
    reader failIfNotAtEnd.
    result ]
```

Do not use this pattern for NDJSON or a stream intentionally containing multiple JSON values. In that case, repeatedly call `next` until `atEnd`.

### 6.3 Keep external property names as strings

For untrusted or open-ended external documents, keep object keys as strings. Converting every arbitrary external property name into a `Symbol` is usually unnecessary. It also makes the boundary less explicit.

Use symbols only when the input vocabulary is bounded and the application deliberately wants symbol keys.

## 7. Loading a schema from disk and binding model classes

`instanceClass:` is runtime Smalltalk metadata. It is not a JSON Schema keyword and is not preserved when a schema is serialized to JSON.

After loading an external schema, bind the relevant object schemas to model classes:

```smalltalk
KgBuildInventory class >> bindInstanceClassesIn: schema
    | projectSchema artifactSchema |

    schema instanceClass: self.

    projectSchema := schema propertyAt: 'project'.
    projectSchema instanceClass: KgBuildProject.

    artifactSchema := (schema propertyAt: 'artifacts') items.
    artifactSchema instanceClass: KgBuildArtifact.

    ^ schema
```

Usage:

```smalltalk
schema := JSONSchema fromString:
    './build-inventory.schema.json' asFileReference contents.

KgBuildInventory bindInstanceClassesIn: schema.

inventory := './build-inventory.json' asFileReference
    readStreamDo: [ :stream |
        schema readFrom: stream ]
```

For schemas with `$ref`, composition, or repeated definitions, centralize binding in a dedicated schema-binder object. Bind by stable schema location or identifier rather than by ad hoc navigation through `properties`.

## 8. Validating nested Dictionaries and Arrays

### 8.1 Generic parsing

```smalltalk
value := NeoJSONReader fromString: jsonString
```

The result is composed of JSON-shaped values:

- object → `Dictionary`;
- array → `Array`;
- string → `String`;
- number → a Smalltalk number;
- boolean → `true` or `false`;
- null → `nil`.

### 8.2 Validation

```smalltalk
schema validate: value
```

On success, validation returns normally. On failure, a subclass of `JSONSchemaError` is signaled.

```smalltalk
isValid := [
    schema validate: value.
    true
]
    on: JSONSchemaError
    do: [ :error | false ]
```

### 8.3 Constructing a nested value manually

```smalltalk
value := Dictionary new
    at: 'schemaVersion' put: 1;
    at: 'generatedAt'
        put: '2026-08-03T20:00:00+02:00';
    at: 'project'
        put: (Dictionary new
            at: 'name' put: 'KlibGenGt';
            at: 'repository'
                put: 'https://github.com/example/KlibGenGt';
            yourself);
    at: 'artifacts'
        put: {
            Dictionary new
                at: 'path' put: 'lib/libgit2.so';
                at: 'kind' put: 'shared-library';
                at: 'size' put: 1827360;
                at: 'tags' put: #('native' 'linux');
                yourself };
    at: 'metadata'
        put: (Dictionary new
            at: 'producer' put: 'klibgen';
            yourself);
    yourself.

schema validate: value
```

Use `Array` for JSON arrays. The current JSONSchema array implementation expects an actual array-shaped value; normalize `OrderedCollection` and other internal collections with `asArray` before validating them as JSON arrays.

### 8.4 Validation does not itself materialize the model

Treat these operations as distinct:

```smalltalk
schema validate: jsonValue       "validate a JSON-shaped object graph"
schema readFrom: stream          "parse, validate, convert, and materialize"
```

For custom model classes, do not assume that `schema read: aDictionary` is equivalent to stream-based materialization. The current implementation's parsed-object path uses dictionary-like `at:put:` operations in places, whereas the streaming path uses the `jsonSchemaAt:put:` model protocol.

## 9. Materializing a model after validating or correcting a parsed graph

When only the parsed graph remains, the simplest reliable bridge is to serialize the normalized graph in memory and read it through the schema:

```smalltalk
schema validate: normalizedValue.

canonicalJson := NeoJSONWriter toString: normalizedValue.
inventory := schema readString: canonicalJson
```

This performs a second pass, but it has several advantages:

- model construction follows the tested streaming path;
- format conversion is applied consistently;
- nested `instanceClass:` bindings are honored;
- no separate reflection-based tree materializer is needed.

For large documents or high-throughput ingestion, implement a direct schema-aware tree materializer. That is one of the main missing pieces discussed later in this document.

When the original JSON string remains unchanged, skip the generic round-trip and materialize directly from the original text after validation only if the validation and materialization schemas are known to be identical.

## 10. A robust tolerant-ingestion pipeline

A tolerant loader should not mix correction with validation or model construction. Use explicit stages:

```text
parse
  -> identify input version
  -> migrate aliases and old versions
  -> normalize deliberately coercible values
  -> validate the canonical JSON-shaped graph
  -> materialize model objects
  -> run domain-level invariants
```

### 10.1 Loader outline

```smalltalk
KgBuildInventoryLoader >> loadFrom: aFileReference
    | raw normalized canonicalJson schema inventory |

    schema := KgBuildInventory jsonSchema.

    raw := self parseExactlyOneValueFrom: aFileReference.
    normalized := self normalize: raw.

    schema validate: normalized.

    canonicalJson := NeoJSONWriter toString: normalized.
    inventory := schema readString: canonicalJson.

    inventory validateDomainInvariants.

    ^ inventory
```

```smalltalk
KgBuildInventoryLoader >> parseExactlyOneValueFrom: aFileReference
    ^ aFileReference readStreamDo: [ :stream |
        | reader value |

        reader := NeoJSONReader on: stream.
        value := reader next.
        reader failIfNotAtEnd.
        value ]
```

### 10.2 Copy before normalization

Do not mutate a caller-owned graph unless the API says so.

```smalltalk
KgBuildInventoryLoader >> normalize: raw
    | normalized artifacts |

    normalized := raw copy.

    self
        moveKey: 'generated_at'
        to: 'generatedAt'
        in: normalized.

    normalized
        at: 'schemaVersion'
        ifAbsentPut: [ 1 ].

    artifacts := normalized
        at: 'artifacts'
        ifAbsentPut: [ #() ].

    normalized
        at: 'artifacts'
        put: ((
            artifacts collect: [ :artifact |
                self normalizeArtifact: artifact copy ])
            asArray).

    ^ normalized
```

```smalltalk
KgBuildInventoryLoader >> normalizeArtifact: artifact
    artifact
        at: 'size'
        ifPresent: [ :size |
            size isString
                ifTrue: [
                    artifact
                        at: 'size'
                        put: (self parseDecimalInteger: size) ] ].

    artifact
        at: 'tags'
        ifPresent: [ :tags |
            artifact at: 'tags' put: tags asArray ].

    ^ artifact
```

### 10.3 Record corrections

A production loader should return or log correction records:

```smalltalk
Object << #KgJsonCorrection
    slots: {
        #path.
        #oldValue.
        #newValue.
        #reason };
    package: 'KlibGen-JSON-Validation'
```

Examples:

```text
/artifacts/0/size: "1827360" -> 1827360
reason: legacy producer emitted decimal integers as strings
```

Do not silently correct ambiguous values. Corrections should be:

- deterministic;
- version-scoped;
- documented;
- test-covered;
- visible in diagnostics.

## 11. Strictness and tolerance strategies

### 11.1 Unknown object properties

Strict canonical schema:

```smalltalk
schema additionalProperties: false
```

Forward-compatible input schema:

```smalltalk
schema additionalProperties: true
```

Typed extension map:

```smalltalk
schema additionalProperties: JSONSchema string
```

A useful pattern is to maintain two contracts:

- an **input compatibility schema**, which accepts documented legacy or extension fields;
- a **canonical schema**, which describes exactly what the application stores and emits.

Normalize from the first to the second.

### 11.2 Missing fields

A property is optional when it is absent from `required`.

Apply defaults during normalization or initialization:

```smalltalk
normalized
    at: 'metadata'
    ifAbsentPut: [ Dictionary new ]
```

Do not confuse an absent property with a present property whose value is JSON `null`.

### 11.3 Null values

JSON `null` maps to `nil`. Nullability and optionality are separate:

- optional: the property may be absent;
- nullable: the property may be present with `null`.

For important null semantics, describe them explicitly in a JSON Schema document using the supported type-array or composition form, and add tests against the exact JSONSchema revision used by the project.

### 11.4 Scalar coercion

JSONSchema should generally validate the wire type rather than guess intent. Perform narrowly defined coercions before validation:

- decimal digit string → integer;
- known historical boolean representation → boolean;
- old timestamp representation → canonical timestamp;
- singleton object → one-element array, only when the protocol explicitly allowed it.

Never apply broad rules such as converting every string that resembles a number.

### 11.5 Aliases and renamed fields

Move old names to canonical names before validation:

```smalltalk
KgBuildInventoryLoader >> moveKey: oldKey to: newKey in: dictionary
    (dictionary includesKey: oldKey)
        ifFalse: [ ^ self ].

    (dictionary includesKey: newKey)
        ifTrue: [
            KgJsonCorrectionConflict signal:
                'Both ',
                oldKey,
                ' and ',
                newKey,
                ' are present' ].

    dictionary
        at: newKey
        put: (dictionary removeKey: oldKey)
```

### 11.6 Version migrations

Read a small stable discriminator first:

```smalltalk
version := raw at: 'schemaVersion' ifAbsent: [ 0 ].

normalized := version
    caseOf: {
        [ 0 ] -> [ self migrateVersion0To1: raw ].
        [ 1 ] -> [ raw copy ] }
    otherwise: [
        KgUnsupportedSchemaVersion signal:
            version printString ]
```

Migrations should produce the canonical current JSON-shaped graph. Validate only after migration, unless the migration itself depends on a version-specific validation pass.

### 11.7 Invalid elements in a large array

For imports where partial success is acceptable, validate elements individually:

```smalltalk
artifactSchema := KgBuildArtifact jsonSchema.

artifacts withIndexDo: [ :artifact :index |
    [
        artifactSchema validate: artifact.
        accepted add: artifact
    ]
        on: JSONSchemaError
        do: [ :error |
            rejected add:
                (KgJsonValidationIssue
                    path: '/artifacts/', (index - 1) asString
                    error: error) ] ]
```

JSON array indices in diagnostic JSON Pointers are zero-based, hence `index - 1`.

Do not use partial acceptance for configuration files that must be internally consistent.

### 11.8 Unknown formats

JSONSchema deliberately tolerates unknown format names. Define a `JSONFormat` subclass for every project-specific format that must be enforced.

```smalltalk
JSONFormatArtifactPath class >> formatName
    ^ 'artifact-path'
```

```smalltalk
JSONFormatArtifactPath class >> basicConvertString: aString
    ^ aString
```

```smalltalk
JSONFormatArtifactPath class >> validateString: aString
    (aString isEmpty
        or: [ aString first = $/ ])
        ifTrue: [
            JSONConstraintError signal:
                aString printString,
                ' is not a relative artifact path' ]
```

Then use:

```smalltalk
JSONSchema stringWithFormat: 'artifact-path'
```

## 12. Error handling

### 12.1 Separate syntax, schema, mapping, and domain errors

The useful categories are:

| Stage | Typical error |
|---|---|
| JSON parsing | `NeoJSONParseError` |
| schema validation/conversion | `JSONSchemaError` subclasses |
| schema-to-model mapping | project mapping error or `MessageNotUnderstood` without a strict base class |
| domain invariants | project-specific validation error |
| file access | filesystem exceptions |

Do not collapse all of them into “invalid JSON”.

### 12.2 JSONSchema exception hierarchy

Catch `JSONSchemaError` for all schema-related failures. More specific classes in the current implementation include:

- `JSONTypeError`;
- `JSONConstraintError`;
- `JSONFormatError`;
- `JSONInvalidPropertyError`;
- `JSONMissingRequiredProperty`;
- `JSONSchemaMissingRequiredProperty`.

There are currently similarly named required-property error classes and different code paths may signal different ones. Catch the common superclass unless a specific distinction has been verified and tested for the pinned revision.

### 12.3 Loader with stage-specific wrapping

```smalltalk
KgBuildInventoryLoader >> loadFrom: file
    | raw normalized schema |

    raw := [
        self parseExactlyOneValueFrom: file
    ]
        on: NeoJSONParseError
        do: [ :error |
            ^ KgJsonLoadResult
                parseFailureFor: file
                cause: error ].

    normalized := self normalize: raw.
    schema := KgBuildInventory jsonSchema.

    [
        schema validate: normalized
    ]
        on: JSONSchemaError
        do: [ :error |
            ^ KgJsonLoadResult
                validationFailureFor: file
                value: normalized
                cause: error ].

    ^ [
        KgJsonLoadResult success: (
            schema readString:
                (NeoJSONWriter toString: normalized))
    ]
        on: Error
        do: [ :error |
            KgJsonLoadResult
                materializationFailureFor: file
                value: normalized
                cause: error ]
```

In debugging builds, preserve the original exception as the cause and provide a GT view that exposes:

- the source file;
- the raw parsed value;
- the normalized value;
- corrections;
- the exception;
- the schema;
- the model class expected at the failing stage.

### 12.4 Fail-fast versus accumulated errors

JSONSchema normally signals the first failure. This is acceptable for programmatic contracts but less useful for user-edited files.

For user-facing validation, add an aggregation layer that returns issues such as:

```smalltalk
Object << #KgJsonValidationIssue
    slots: {
        #path.
        #code.
        #message.
        #expected.
        #actual.
        #cause };
    package: 'KlibGen-JSON-Validation'
```

Use JSON Pointer paths:

```text
/project/name
/artifacts/0/size
/artifacts/3/kind
```

An aggregation layer is part of the missing Pydantic-like layer described below.

## 13. Writing model objects

### 13.1 Buffered schema-directed writing

```smalltalk
jsonString := KgBuildInventory jsonSchema write: inventory
```

This is the simplest API. It buffers the complete JSON string.

### 13.2 Writing to an existing character stream

```smalltalk
schema := KgBuildInventory jsonSchema.

schema write: inventory on:
    (JSONSchemaWriter on: aCharacterStream)
```

Pretty-printed output:

```smalltalk
| writer |

writer := JSONSchemaWriter on: aCharacterStream.
writer prettyPrint: true.
schema write: inventory on: writer
```

### 13.3 Writing to disk

```smalltalk
target := './build-inventory.json' asFileReference.
schema := KgBuildInventory jsonSchema.

target writeStreamDo: [ :stream |
    | writer |

    writer := JSONSchemaWriter on: stream.
    writer prettyPrint: true.
    schema write: inventory on: writer ]
```

`writeStreamDo:` closes the stream even if the block exits abnormally.

### 13.4 Validated output pipeline

The current schema writer validates primitive values as it writes and checks required object properties, but application code should not assume that every object-level composition and constraint is exhaustively preflighted for arbitrary custom model objects.

For important output, validate the actual emitted JSON-shaped value:

```smalltalk
jsonString := schema write: inventory.
emittedValue := NeoJSONReader fromString: jsonString.
schema validate: emittedValue.

target writeStreamDo: [ :stream |
    stream nextPutAll: jsonString ]
```

This also tests the agreement between:

- model accessors;
- schema property names;
- nested model classes;
- custom formats;
- writer behavior.

### 13.5 Direct NeoJSON output followed by schema validation

When NeoJSON mapping is the canonical serializer:

```smalltalk
jsonString := String streamContents: [ :stream |
    (NeoJSONWriter on: stream)
        prettyPrint: true;
        nextPut: inventory ].

schema validate:
    (NeoJSONReader fromString: jsonString)
```

Write only after validation succeeds.

### 13.6 Crash-safe replacement

For important generated files:

1. serialize and validate in memory;
2. write a temporary file in the same directory;
3. flush and close it;
4. replace the destination using the project's platform-aware atomic-replace helper;
5. retain or report the old file if replacement fails.

Do not label a delete-then-move sequence “atomic”; it is not crash-safe and may behave differently across operating systems.

## 14. Serializing the schema itself

```smalltalk
schemaJson := schema jsonString.
prettySchemaJson := schema jsonStringPretty
```

Writing to disk:

```smalltalk
'./build-inventory.schema.json' asFileReference
    writeStreamDo: [ :stream |
        stream nextPutAll: schema jsonStringPretty ]
```

Remember that Smalltalk-only information is not part of the schema document:

- `instanceClass:`;
- NeoJSON mappings;
- correction rules;
- domain invariants;
- project-specific error presentation.

Reapply these after loading the schema.

## 15. Recommended reusable façade

Do not spread raw NeoJSON and JSONSchema calls throughout the application. Introduce a small project façade.

```smalltalk
Object << #KgJsonCodec
    package: 'KlibGen-JSON'
```

```smalltalk
KgJsonCodec >> readExactly: schema from: stream
    | reader result |

    reader := NeoJSONReader on: stream.
    result := schema readUsing: reader.
    reader failIfNotAtEnd.

    ^ result
```

```smalltalk
KgJsonCodec >> parseExactlyFrom: stream
    | reader result |

    reader := NeoJSONReader on: stream.
    result := reader next.
    reader failIfNotAtEnd.

    ^ result
```

```smalltalk
KgJsonCodec >> materialize: jsonValue using: schema
    schema validate: jsonValue.

    ^ schema readString:
        (NeoJSONWriter toString: jsonValue)
```

```smalltalk
KgJsonCodec >> validatedJsonFor: model using: schema pretty: pretty
    | json value |

    json := String streamContents: [ :stream |
        | writer |

        writer := JSONSchemaWriter on: stream.
        writer prettyPrint: pretty.
        schema write: model on: writer ].

    value := NeoJSONReader fromString: json.
    schema validate: value.

    ^ json
```

This façade is a natural place to add:

- metrics;
- source locations;
- exception wrapping;
- schema registry lookup;
- correction reports;
- limits on file size and nesting;
- canonical formatting;
- GT views.

## 16. Testing checklist

### 16.1 Successful nested materialization

```smalltalk
KgBuildInventoryTest >> testReadsNestedInventory
    | inventory |

    inventory := KgBuildInventory jsonSchema
        readString: self validInventoryJson.

    self assert: inventory class equals: KgBuildInventory.
    self assert: inventory project class equals: KgBuildProject.
    self assert: inventory artifacts first class equals: KgBuildArtifact.
    self assert: inventory generatedAt class equals: DateAndTime
```

### 16.2 Wrong nested type

```smalltalk
KgBuildInventoryTest >> testRejectsStringArtifactSize
    self
        should: [
            KgBuildInventory jsonSchema
                readString: self inventoryWithStringSizeJson ]
        raise: JSONSchemaError
```

### 16.3 Unknown field policy

```smalltalk
KgBuildInventoryTest >> testRejectsUnknownArtifactField
    self
        should: [
            KgBuildInventory jsonSchema
                readString: self inventoryWithUnknownArtifactFieldJson ]
        raise: JSONSchemaError
```

### 16.4 Round trip

```smalltalk
KgBuildInventoryTest >> testRoundTripProducesValidJson
    | schema inventory json value |

    schema := KgBuildInventory jsonSchema.
    inventory := schema readString: self validInventoryJson.

    json := schema write: inventory.
    value := NeoJSONReader fromString: json.

    self shouldnt: [ schema validate: value ] raise: JSONSchemaError
```

### 16.5 Trailing input

```smalltalk
KgBuildInventoryTest >> testRejectsTrailingInput
    | reader schema |

    schema := KgBuildInventory jsonSchema.
    reader := NeoJSONReader on:
        (self validInventoryJson, ' false') readStream.

    schema readUsing: reader.

    self
        should: [ reader failIfNotAtEnd ]
        raise: NeoJSONParseError
```

### 16.6 Migration and correction

Test:

- every supported old version;
- every alias;
- every coercion;
- conflicts between old and new names;
- correction records;
- idempotence of normalization.

```smalltalk
self
    assert: (normalizer normalize:
        (normalizer normalize: input))
    equals: (normalizer normalize: input)
```

### 16.7 Schema snapshot

Keep a reviewed schema snapshot in the repository and compare it with the generated schema, ignoring formatting if necessary. This catches accidental contract changes caused by edits to model metadata.

## 17. Known limitations and sharp edges

1. **JSONSchema is not a complete implementation of every current JSON Schema vocabulary.** Remote `$ref`, dynamic references, unevaluated properties/items, and some other newer features are not supported.

2. **Pin and test the revision.** The project was actively fixing official-suite failures when this guide was prepared.

3. **Validation is fail-fast.** It does not provide a Pydantic-style list of path-aware issues.

4. **`instanceClass:` is not serialized.** Rebind model classes after loading an external schema.

5. **Stream materialization and parsed-tree reading are not equivalent for custom classes.** Prefer `readFrom:`/`readUsing:` for model construction.

6. **The default model setter can silently ignore a property.** Use a strict model superclass.

7. **Unknown formats are tolerated.** Register custom formats when format enforcement matters.

8. **Optional and nullable are distinct.** Add explicit tests for `nil` behavior.

9. **Generic collections are not always JSON arrays.** Normalize sequenceable collections to `Array`.

10. **Convenience parsing may not reject trailing input.** Call `failIfNotAtEnd` when exactly one value is required.

11. **Schema-valid JSON is not necessarily domain-valid.** Run invariants such as path uniqueness, cross-reference integrity, and compatibility rules after materialization.

---

# 18. The missing part: a Pydantic-like model layer for Pharo

NeoJSON and JSONSchema provide most of the execution machinery, but application code still duplicates declarations across:

- class slots;
- accessors;
- NeoJSON mappings;
- JSONSchema construction;
- required-field lists;
- aliases and migration rules;
- defaults;
- model binding;
- validation diagnostics;
- GT views and examples.

A thin Pharo layer could make one model description the source of truth and generate or derive the rest.

## 18.1 A reasonable first-version goal

A first version should support:

- explicitly declared model classes;
- field descriptors;
- JSON property names and aliases;
- required and optional fields;
- schema factories;
- nested models and collections;
- defaults;
- pre-validation normalizers;
- post-materialization validators;
- NeoJSON mapping generation;
- JSONSchema generation;
- strict model materialization;
- path-aware error aggregation;
- schema export;
- GT views;
- deterministic source generation where code is generated.

It should not initially attempt to implement the whole JSON Schema standard or replace NeoJSON/JSONSchema.

## 18.2 Recommended metadata model

Start with ordinary class-side methods returning descriptor objects. This is explicit, inspectable, easy to debug, and easy to version.

```smalltalk
KgBuildArtifact class >> jsonModel
    ^ KgJsonModelDescriptor for: self configure: [ :model |
        model
            additionalProperties: false;
            field: #path configure: [ :field |
                field
                    jsonName: 'path';
                    schema: [ JSONSchema string ];
                    required: true ];
            field: #kind configure: [ :field |
                field
                    jsonName: 'kind';
                    schema: [
                        JSONSchema string enum: #(
                            'shared-library'
                            'executable'
                            'resource') ];
                    required: true ];
            field: #size configure: [ :field |
                field
                    jsonName: 'size';
                    schema: [
                        | schema |
                        schema := JSONSchema integer.
                        schema interval minimum: 0.
                        schema ];
                    required: true ];
            field: #tags configure: [ :field |
                field
                    jsonName: 'tags';
                    schema: [
                        JSONSchemaArray new
                            items: JSONSchema string;
                            yourself ];
                    default: [ #() ] ] ]
```

Possible field attributes:

```text
slotName
jsonName
aliases
schemaBlock
required
defaultBlock
decoder
encoder
normalizer
omitIfNil
deprecatedSince
documentation
examples
```

## 18.3 Generate JSONSchema from descriptors

```smalltalk
KgJsonModelDescriptor >> buildSchema
    | properties schema |

    properties := fields collect: [ :field |
        field jsonName -> field schema ].

    schema := properties asArray asJSONSchema.

    schema
        instanceClass: modelClass;
        required: (
            fields
                select: #isRequired
                thenCollect: #jsonName);
        additionalProperties: additionalProperties.

    ^ schema
```

Nested model field:

```smalltalk
field
    jsonName: 'project';
    schema: [ KgBuildProject jsonModel schema ];
    required: true
```

Typed model list:

```smalltalk
field
    jsonName: 'artifacts';
    schema: [
        JSONSchemaArray new
            items: KgBuildArtifact jsonModel schema;
            yourself ];
    required: true
```

## 18.4 Generate NeoJSON mappings from the same descriptors

A common model superclass can inherit a generic class-side mapping method:

```smalltalk
KgJsonModel class >> neoJsonMapping: mapper
    | descriptor |

    descriptor := self jsonModel.

    mapper
        for: self
        do: [ :mapping |
            descriptor fields do: [ :field |
                | propertyMapping |

                propertyMapping := mapping
                    mapAccessor: field slotName
                    to: field jsonName.

                field neoJsonValueSchema
                    ifNotNil: [ :valueSchema |
                        propertyMapping
                            valueSchema: valueSchema ] ] ].

    descriptor registerAuxiliaryMappingsOn: mapper
```

`neoJsonValueSchema` can be:

- a nested model class;
- a symbolic typed-list schema;
- `DateAndTime`;
- another custom mapping identifier.

This eliminates most hand-written `neoJsonMapping:` methods.

## 18.5 Use pragmas when metadata belongs next to methods

Pharo pragmas are useful when a field is represented by an accessor or schema-producing method.

```smalltalk
KgBuildArtifact class >> jsonSchemaForPath
    <jsonField: #path
        name: 'path'
        required: true>

    ^ JSONSchema string
```

```smalltalk
KgBuildArtifact class >> jsonSchemaForSize
    <jsonField: #size
        name: 'size'
        required: true>

    | schema |

    schema := JSONSchema integer.
    schema interval minimum: 0.
    ^ schema
```

A descriptor builder can scan class-side methods:

```smalltalk
KgJsonPragmaDescriptorBuilder >> fieldsFor: modelClass
    ^ modelClass classSide methods
        flatCollect: [ :method |
            method pragmas
                select: [ :pragma |
                    pragma selector =
                        #jsonField:name:required: ]
                thenCollect: [ :pragma |
                    self
                        fieldFrom: pragma
                        schema: (
                            modelClass
                                perform: method selector) ] ]
```

Advantages:

- metadata is close to the schema factory;
- ordinary methods can compute complex schemas;
- pragmas are visible to tools;
- GT can navigate from a field descriptor to its defining method.

Disadvantages:

- one method per field can be verbose;
- pragma selectors become part of the metadata protocol;
- multi-variant metadata may require several pragmas or descriptor objects.

## 18.6 Use first-class slots when metadata belongs to storage

Pharo slots are real objects. Custom `Slot` subclasses can participate in class compilation and customize generated access.

Potential uses:

- attach JSON field metadata to the slot;
- generate getter and setter behavior;
- enforce assignment-time invariants;
- track whether a property was present versus defaulted;
- implement observable fields for GT tools;
- preserve unknown raw values next to normalized values.

Fluid class syntax already supports slot classes:

```smalltalk
KgJsonModel << #KgGeneratedArtifact
    slots: {
        #path => KgJsonSlot.
        #kind => KgJsonSlot.
        #size => KgJsonSlot };
    package: 'KlibGen-JSON-Generated'
```

A more sophisticated configured slot could carry a descriptor, but exact custom-slot construction should follow the slot protocol of the target Pharo/GToolkit version.

Custom slots are powerful but should not be the first implementation step. Descriptor methods are easier to load, inspect, debug, and keep compatible.

## 18.7 Generate model classes with the fluid class builder

Pharo's fluid class definition is message-based and can be used programmatically:

```smalltalk
modelClass := KgJsonModel << descriptor className
    slots: descriptor slotNames;
    package: descriptor packageName
```

Then generate accessors:

```smalltalk
descriptor fields do: [ :field |
    modelClass
        compile: field readerSource
        classified: 'accessing'.

    modelClass
        compile: field writerSource
        classified: 'accessing' ]
```

Example generated reader source:

```smalltalk
KgJsonFieldDescriptor >> readerSource
    ^ slotName asString,
        String cr,
        String tab,
        '^ ',
        slotName asString
```

Example generated writer source:

```smalltalk
KgJsonFieldDescriptor >> writerSource
    ^ slotName asString,
        ': anObject',
        String cr,
        String tab,
        slotName asString,
        ' := anObject'
```

For schemas imported from JSON Schema or OpenAPI, create all class shells first, then bind fields. This is necessary for recursive and mutually recursive schemas.

## 18.8 Use Ring for source-oriented generation

Ring is Pharo's code metamodel. It is suitable when generation should:

- build a complete model without immediately modifying the live system;
- compare proposed generated code with existing code;
- emit deterministic source;
- support previews and review;
- write Tonel-managed classes and methods;
- apply changes as a controlled transaction.

A robust generator can:

1. build Ring class and method definitions;
2. render a proposed package;
3. show a GT diff;
4. let the developer accept or reject changes;
5. compile or write the accepted definitions.

For a first implementation, direct class building and `compile:classified:` are sufficient. Ring becomes valuable once regeneration and source review matter.

## 18.9 Use traits for shared generated behavior

Traits can provide:

- strict `jsonSchemaAt:` access;
- common class-side `jsonSchema`;
- generic `neoJsonMapping:`;
- `fromJsonString:` and `writeJsonOn:`;
- domain-validation hooks;
- GT views;
- equality or printing for DTOs.

Example conceptual composition:

```smalltalk
KgJsonModel << #KgBuildArtifact
    traits: { TKGJsonModel };
    slots: { #path. #kind. #size. #tags };
    package: 'KlibGen-JSON-Model'
```

Keep field-specific generated code in the model class and reusable behavior in the trait.

## 18.10 Cache generated schemas safely

Schema construction may be cached, but caches must be invalidated when model metadata changes.

A registry is preferable to hidden global class properties:

```smalltalk
KgJsonSchemaRegistry >> schemaFor: modelClass
    ^ schemas
        at: modelClass
        ifAbsentPut: [
            modelClass jsonModel buildSchema ]
```

```smalltalk
KgJsonSchemaRegistry >> flushFor: modelClass
    schemas removeKey: modelClass ifAbsent: [ ]
```

In a live image, the registry can subscribe to system announcements for relevant class and method changes. The exact announcement classes vary across Pharo versions, so isolate that integration behind one adapter and test it in the target GToolkit image.

## 18.11 Add a direct tree materializer

The current practical bridge from a validated `Dictionary`/`Array` graph to models is a JSON round trip. A Pydantic-like layer should walk the graph directly:

```smalltalk
KgJsonTreeMaterializer >> materialize: value as: descriptor at: path
    descriptor isObject
        ifTrue: [
            ^ self
                materializeObject: value
                as: descriptor
                at: path ].

    descriptor isArray
        ifTrue: [
            ^ value withIndexCollect: [ :each :index |
                self
                    materialize: each
                    as: descriptor elementDescriptor
                    at: path / (index - 1) ] ].

    ^ descriptor convertAndValidate: value at: path
```

Object materialization:

```smalltalk
KgJsonTreeMaterializer >> materializeObject: dictionary as: descriptor at: path
    | object |

    object := descriptor modelClass new.

    descriptor fields do: [ :field |
        dictionary
            at: field jsonName
            ifPresent: [ :rawValue |
                object
                    perform: field writerSelector
                    with: (
                        self
                            materialize: rawValue
                            as: field valueDescriptor
                            at: path / field jsonName) ]
            ifAbsent: [
                field applyDefaultTo: object ] ].

    ^ object
```

This layer can collect issues rather than raising immediately.

## 18.12 Add path-aware accumulated validation

The issue type should be independent of exception text:

```smalltalk
KgJsonValidationIssue class >>
path: path
code: code
message: message
expected: expected
actual: actual
cause: cause
```

Suggested codes:

```text
parse-error
wrong-type
missing-required
unknown-property
constraint-failed
invalid-format
invalid-enum
normalization-conflict
mapping-error
domain-invariant
```

The result can be:

```smalltalk
Object << #KgJsonValidationResult
    slots: {
        #value.
        #issues.
        #corrections };
    package: 'KlibGen-JSON-Validation'
```

This is the largest user-facing difference between raw JSONSchema and Pydantic/Konform-like systems.

## 18.13 Use GToolkit views and examples

The metadata layer should be moldable.

Useful views:

- model fields;
- generated JSON Schema;
- NeoJSON mapping;
- sample JSON;
- required versus optional fields;
- aliases and migrations;
- validation issues grouped by path;
- corrections;
- model/schema source links;
- dependency graph between model classes.

Example view outline:

```smalltalk
KgJsonModelDescriptor >> gtFieldsFor: aView
    <gtView>

    ^ aView columnedList
        title: 'JSON fields';
        items: [ self fields ];
        column: 'JSON name'
            text: [ :field | field jsonName ];
        column: 'Slot'
            text: [ :field | field slotName ];
        column: 'Required'
            text: [ :field | field isRequired ];
        column: 'Schema'
            text: [ :field | field schema printString ]
```

Use `<gtExample>` methods for:

- minimal valid payload;
- complete payload;
- legacy payload and expected corrections;
- invalid payload and expected issue paths;
- round-trip invariants.

Executable examples make the model contract inspectable and testable in the image.

## 18.14 Recommended implementation order

1. **Project façade** around NeoJSON and JSONSchema.
2. **Strict model base class** and domain-specific errors.
3. **Class-side descriptor objects** for hand-written model classes.
4. **Generated JSONSchema** from descriptors.
5. **Generic inherited NeoJSON mapping** from descriptors.
6. **Correction and migration pipeline**.
7. **Path-aware validation result**.
8. **Direct tree materializer**.
9. **GT views and examples**.
10. **Optional class and accessor generation**.
11. **Ring-based source preview and deterministic regeneration**.
12. **Optional custom slots** when their compiler-level behavior provides a concrete benefit.

This order yields value early without coupling the first version to the most version-sensitive parts of Pharo's metaprogramming infrastructure.

## 19. References

- [NeoJSON repository](https://github.com/svenvc/NeoJSON)
- [NeoJSON introduction in Enterprise Pharo](https://books.pharo.org/enterprise-pharo/)
- [ApptiveGrid/JSONSchema repository](https://github.com/ApptiveGrid/JSONSchema)
- [JSON Schema specification](https://json-schema.org/)
- [Pharo fluid class definition documentation](https://github.com/pharo-project/pharo/blob/Pharo13/doc/FluidClassDefinition/FluidClassDefinition.md)
- [GToolkit: working with the file system](https://book.gtoolkit.com/how-to-work-with-the-file-system-6k5konqi6zaag5grq59vhc523)
