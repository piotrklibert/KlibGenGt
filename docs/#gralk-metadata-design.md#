# GradT pragma metadata draft

## 0. Scope

GradT annotations are stored as Smalltalk pragmas on methods. The annotated
method may be:

1. the actual implementation method being annotated;
2. a declaration-only method in a sidecar provider class;
3. an extension/helper declaration method owned by another package.

Pragmas are not the checker’s internal model. Pragmas are a **source/storage
format**. During loading or analysis, GradT scans pragmas, validates them, and
normalizes them into registry objects.

The registry is the authoritative API for typechecking, contract checking,
tooling, and runtime instrumentation.

---

## 1. Declaration locations

### 1.1 Inline declaration

Used when the method/class is owned by the package being typed.

```smalltalk
Account >> withdraw: amount
  <gradTMethodReturn: #Account>
  <gradTParam: #amount type: #Number>
  <gradTRequires: #(amount #> 0)>
  <gradTEnsures: #(balance #>= 0)>
  balance := balance - amount.
```

### 1.2 Sidecar declaration

Used to annotate classes and methods that GradT does not own.

```smalltalk
GradTCollectionsTypes >> orderedCollectionAdd
  <gradTMethod:
    #OrderedCollection
    side: #instance
    selector: #add:
    arguments: #(#Element)
    returns: #Element>
```

The method body is irrelevant. It may be empty, return `self`, or return a
declaration object for browsing/debugging. The pragma is the declaration.

### 1.3 Provider class

A provider class groups declarations for an external package or subsystem.

```smalltalk
Object subclass: #GradTCollectionsTypes
  instanceVariableNames: ''
  classVariableNames: ''
  package: 'GradT-Types-Collections'
```

Provider classes may optionally carry package-level metadata:

```smalltalk
GradTCollectionsTypes >> packageMetadata
  <gradTProvider:
    #Collections
    targetPackage: #Collections
    version: '0.1'>
```

---

## 2. Common declaration metadata

Every declaration should normalize to a common header:

```text
GradTDeclaration
  id
  kind
  ownerPackage
  providerMethod
  target
  priority
  overlay
  applicability
  sourceFingerprint
  dependencies
  status
```

### 2.1 Required conceptual fields

`kind`

One of:

```text
#class
#method
#slot
#alias
#structuralType
#contract
#invariant
#blockEffect
#slotSemantics
#constructor
#initializer
#effect
```

`ownerPackage`

The package that supplied the declaration.

`providerMethod`

The compiled method containing the pragma. Useful for browsing, invalidation, and blame.

`target`

The class, method, slot, package, or type alias being described.

### 2.2 Optional common fields

`sourceFingerprint`

A hash or version stamp of the target implementation expected by the declaration.

Used mostly for sidecar declarations.

```smalltalk
<gradTMethod:
  #OrderedCollection
  side: #instance
  selector: #add:
  arguments: #(#Element)
  returns: #Element
  sourceHash: 'sha256:...'>
```

`priority`

Used when multiple declarations target the same entity.

```smalltalk
<gradTPriority: 100>
```

`overlay`

Names an overlay or compatibility profile.

```smalltalk
<gradTOverlay: #Pharo12>
```

`applicability`

Conditions under which the declaration applies.

Examples:

```smalltalk
<gradTAppliesWhen: #(pharoVersion #>= 12)>
<gradTAppliesWhen: #(packageVersion #Collections #= '12.0')>
```

The first implementation can treat this as metadata only and flag unsupported applicability clauses.

---

## 3. Type literal format

Type expressions inside pragmas should use literal-safe Smalltalk objects: symbols, arrays, numbers, strings, booleans, and nil.

GradT may accept token-style syntax initially, but the registry should normalize everything into a type AST.

### 3.1 Minimal type literals

Nominal type:

```smalltalk
#String
#Number
#UndefinedObject
```

Special types:

```smalltalk
#Any
#Self
#SelfClass
#Never
```

Union:

```smalltalk
#(#String #| #UndefinedObject)
```

Generic type:

```smalltalk
#(OrderedCollection #< #String #>)
```

Nested generic/union:

```smalltalk
#(OrderedCollection #< #(#Number #| #String) #>)
```

Block type:

```smalltalk
#(BlockClosure #< #Element #-> #Result #>)
```

Multiple-argument block:

```smalltalk
#(BlockClosure #< #Element #Integer #-> #String #>)
```

Structural/protocol type:

```smalltalk
#(Structural #(
  (#size #() #Integer)
  (#at: (#Integer) #Element)
))
```

Receiver-family collection type:

```smalltalk
#(ReceiverCollection #< #Element #>)
```

This is useful for methods such as `select:` that should return the same collection family as the receiver.

### 3.2 Normalized internal types

The registry should normalize the above into internal objects:

```text
GradTNominalType(name)
GradTGenericType(name, arguments)
GradTUnionType(alternatives)
GradTBlockType(argumentTypes, returnType, effects)
GradTStructuralType(methodSignatures)
GradTSelfType
GradTNeverType
GradTAnyType
```

The checker should never operate directly on pragma literal arrays.

---

## 4. Class declarations

Class declarations describe generic parameters, superclass typing, class-side typing, and optional object-model assumptions.

Example:

```smalltalk
GradTCollectionsTypes >> collectionClass
  <gradTClass:
    #Collection
    typeParameters: #(Element)
    superclass: #Object>
```

```smalltalk
GradTCollectionsTypes >> orderedCollectionClass
  <gradTClass:
    #OrderedCollection
    typeParameters: #(Element)
    superclass: #(SequenceableCollection #< #Element #>)>
```

Suggested normalized fields:

```text
GradTClassDeclaration
  className
  typeParameters
  superclassType
  traitTypes
  classSideTypeParameters
  objectModelPolicy
  ownerPackage
  sourceFingerprint
```

Possible object-model flags:

```text
#normalObject
#protoObjectSubclass
#specialObject
#external
#unknown
```

This matters because GradT may initially assume most classes inherit from `Object`, while Pharo contains direct `ProtoObject` subclasses.

---

## 5. Type aliases

Aliases allow a Smalltalk-friendly name for complex types.

```smalltalk
GradTKernelTypes >> maybeString
  <gradTAlias:
    #MaybeString
    type: #(#String #| #UndefinedObject)>
```

Structural nil protocol alias:

```smalltalk
GradTKernelTypes >> nilControlProtocol
  <gradTAlias:
    #NilControlProtocol
    type: #(Structural #(
      (#isNil #() #Boolean)
      (#notNil #() #Boolean)
      (#ifNil: (#(BlockClosure #< #-> #Any #>)) #Any)
      (#ifNotNil: (#(BlockClosure #< #Any #-> #Any #>)) #Any)
    ))>
```

Suggested normalized fields:

```text
GradTTypeAliasDeclaration
  aliasName
  typeExpression
  visibility
  ownerPackage
```

---

## 6. Method signatures

Method declarations describe argument and return types.

```smalltalk
GradTCollectionsTypes >> orderedCollectionAdd
  <gradTMethod:
    #OrderedCollection
    side: #instance
    selector: #add:
    arguments: #(#Element)
    returns: #Element>
```

Class-side method:

```smalltalk
GradTCollectionsTypes >> orderedCollectionNew
  <gradTMethod:
    #OrderedCollection
    side: #class
    selector: #new
    arguments: #()
    returns: #(OrderedCollection #< #Element #>)>
```

Generic method:

```smalltalk
GradTCollectionsTypes >> collectionCollect
  <gradTMethod:
    #Collection
    side: #instance
    selector: #collect:
    typeParameters: #(Result)
    arguments: #((BlockClosure #< #Element #-> #Result #>))
    returns: #(ReceiverCollection #< #Result #>)>
```

Suggested normalized fields:

```text
GradTMethodDeclaration
  targetClassName
  side
  selector
  receiverType
  methodTypeParameters
  argumentTypes
  returnType
  effectSummary
  blockArgumentSummaries
  preconditions
  postconditions
  sourceFingerprint
  overridePolicy
```

### 6.1 Inline parameter declarations

For implementation methods, it may be more readable to use separate param pragmas:

```smalltalk
Account >> transfer: amount to: otherAccount
  <gradTParam: #amount type: #Number>
  <gradTParam: #otherAccount type: #Account>
  <gradTReturns: #Boolean>
```

The registry should merge these into the same `GradTMethodDeclaration` shape.

---

## 7. Slot declarations

Slot declarations describe logical slot type and initialization policy. They should not assume all Pharo slots are plain ivars.

Example:

```smalltalk
GradTAccountTypes >> balanceSlot
  <gradTSlot:
    #Account
    name: #balance
    type: #Number
    initialization: #required
    storage: #ordinary>
```

Lateinit-style slot:

```smalltalk
GradTAccountTypes >> ownerSlot
  <gradTSlot:
    #Account
    name: #owner
    type: #Person
    initialization: #lateinit
    storage: #ordinary>
```

Nullable slot:

```smalltalk
GradTAccountTypes >> noteSlot
  <gradTSlot:
    #Account
    name: #note
    type: #(#String #| #UndefinedObject)
    initialization: #nullable
    storage: #ordinary>
```

Computed/defaulted slot:

```smalltalk
GradTWidgetTypes >> cachedExtentSlot
  <gradTSlot:
    #Widget
    name: #cachedExtent
    type: #Point
    initialization: #computed
    storage: #computed>
```

Suggested normalized fields:

```text
GradTSlotDeclaration
  targetClassName
  slotName
  type
  initializationPolicy
  storageKind
  readContract
  writeContract
  invariantContribution
  sourceFingerprint
```

Initialization policies:

```text
#nullable
  Physical nil is allowed; read type includes UndefinedObject.

#required
  Must be initialized by constructors/initializers before stable use.

#lateinit
  May start nil/uninitialized; reads before proven write are errors or runtime failures.

#defaulted
  May be physically nil, but read semantics guarantee a value.

#computed
  Read is computed; definite-assignment tracking does not apply.

#external
  GradT does not reason about initialization.

#unknown
  Declaration exists but no DA assumptions are made.
```

Storage kinds:

```text
#ordinary
#decorated
#computed
#virtual
#external
#unknown
```

---

## 8. Slot-class semantics

Because Pharo slots are first-class objects, GradT needs metadata about slot classes themselves.

Example:

```smalltalk
GradTSlotSemanticsTypes >> instanceVariableSlotSemantics
  <gradTSlotClass:
    #InstanceVariableSlot
    storage: #ordinary
    readEffect: #pure
    writeEffect: #directStore
    writeImpliesInitialized: true>
```

For a custom typed slot:

```smalltalk
GradTSlotSemanticsTypes >> typedSlotSemantics
  <gradTSlotClass:
    #TypedSlot
    storage: #decorated
    readEffect: #pure
    writeEffect: #checkedStore
    writeImpliesInitialized: true>
```

For an unknown or reflective slot class:

```smalltalk
GradTSlotSemanticsTypes >> reflectiveSlotSemantics
  <gradTSlotClass:
    #ReflectiveSlot
    storage: #unknown
    readEffect: #mayRunCode
    writeEffect: #mayRunCode
    writeImpliesInitialized: false>
```

Suggested normalized fields:

```text
GradTSlotClassSemanticsDeclaration
  slotClassName
  storageKind
  readEffect
  writeEffect
  writeImpliesInitialized
  readBeforeWriteAllowed
  supportsDefiniteAssignment
```

---

## 9. Constructors and initializers

Smalltalk has conventions, not enforced constructors. GradT should make constructor/initializer contracts explicit.

Initializer:

```smalltalk
Person >> initialize
  <gradTInitializer>
  super initialize.
  name := 'Anonymous'.
```

Constructor/factory:

```smalltalk
Person class >> named: aString
  <gradTConstructor>
  <gradTParam: #aString type: #String>
  <gradTEnsuresSlots: #(name)>
  ^ self new
      name: aString;
      yourself
```

Bypasses normal initialize:

```smalltalk
Person class >> basicNamed: aString
  <gradTConstructorWithoutInitialize>
  <gradTParam: #aString type: #String>
  <gradTEnsuresSlots: #(name)>
```

Suggested normalized fields:

```text
GradTConstructorDeclaration
  targetClassName
  side
  selector
  kind
  initializesSlots
  requiresSuperInitialize
  bypassesInitialize
```

Initializer kinds:

```text
#initializer
#constructor
#constructorWithoutInitialize
#factory
#unknown
```

---

## 10. Contracts

Contracts are runtime-checkable assumptions that may also expose static facts.

### 10.1 Preconditions

```smalltalk
Account >> withdraw: amount
  <gradTRequires: #(amount #> 0)>
  <gradTRequires: #(amount isKindOf: #Number)>
```

### 10.2 Postconditions

```smalltalk
Account >> withdraw: amount
  <gradTEnsures: #(balance #>= 0)>
```

With old values:

```smalltalk
Account >> withdraw: amount
  <gradTOld: #oldBalance expression: #balance>
  <gradTEnsures: #(balance #= (oldBalance #- amount))>
```

### 10.3 Class invariants

```smalltalk
GradTAccountContracts >> accountInvariant
  <gradTInvariant:
    #Account
    expression: #(balance #>= 0)>
```

### 10.4 Slot-related facts

```smalltalk
Person >> ensureName
  <gradTEnsuresSlots: #(name)>
  name isNil ifTrue: [ name := 'Anonymous' ].
```

```smalltalk
Person >> displayName
  <gradTRequiresSlots: #(name)>
  ^ name asUppercase
```

Suggested normalized fields:

```text
GradTContractDeclaration
  kind
  target
  expression
  staticMeaning
  runtimePredicate
  blamePolicy
  cost
  purity
  dependencies
```

Contract kinds:

```text
#requires
#ensures
#invariant
#old
#requiresSlots
#ensuresSlots
#readContract
#writeContract
#typeBoundary
```

Static meanings:

```text
#none
#refinesType
#excludesNil
#requiresInitializedSlot
#ensuresInitializedSlot
#invalidatesFacts
#establishesInvariant
```

---

## 11. Block and control-effect metadata

Blocks need metadata beyond argument and return types.

Example for `Collection>>do:`:

```smalltalk
GradTCollectionsControl >> collectionDo
  <gradTMethod:
    #Collection
    side: #instance
    selector: #do:
    arguments: #((BlockClosure #< #Element #-> #Any #>))
    returns: #Self>
  <gradTBlockArg:
    1
    invocation: #zeroOrMore
    escape: #noescape
    execution: #synchronous
    nonLocalReturn: #allowed>
```

Example for `Boolean>>ifTrue:ifFalse:`:

```smalltalk
GradTKernelControl >> booleanIfTrueIfFalse
  <gradTControl:
    #Boolean
    side: #instance
    selector: #ifTrue:ifFalse:
    blocks: #(
      (1 invocation: exactlyOnceWhenReceiverTrue
         escape: noescape
         execution: synchronous
         nonLocalReturn: allowed)
      (2 invocation: exactlyOnceWhenReceiverFalse
         escape: noescape
         execution: synchronous
         nonLocalReturn: allowed))>
```

Example for callback registration:

```smalltalk
GradTUIControl >> buttonWhenPressedDo
  <gradTBlockArg:
    1
    invocation: #unknown
    escape: #escapes
    execution: #asynchronous
    nonLocalReturn: #forbidden>
```

Suggested normalized fields:

```text
GradTBlockArgumentDeclaration
  targetMethod
  argumentIndex
  blockType
  invocation
  escape
  execution
  nonLocalReturn
  capturedMutationPolicy
```

Invocation values:

```text
#never
#zeroOrOne
#exactlyOnce
#zeroOrMore
#oneOrMore
#unknown
#exactlyOnceWhenReceiverTrue
#exactlyOnceWhenReceiverFalse
```

Escape values:

```text
#noescape
#mayEscape
#escapes
#unknown
```

Execution values:

```text
#synchronous
#asynchronous
#unknown
```

Non-local return values:

```text
#allowed
#forbidden
#unknown
```

Captured mutation policy:

```text
#propagate
#join
#invalidate
#ignore
#unknown
```

---

## 12. Control-form declarations

Some selectors should be lowered into GradT control-flow IR rather than treated as ordinary sends.

Examples:

```smalltalk
GradTKernelControl >> ifTrue
  <gradTControlForm:
    #Boolean
    side: #instance
    selector: #ifTrue:
    lowering: #if>
```

```smalltalk
GradTKernelControl >> whileTrue
  <gradTControlForm:
    #BlockClosure
    side: #instance
    selector: #whileTrue:
    lowering: #while>
```

```smalltalk
GradTKernelControl >> ensure
  <gradTControlForm:
    #BlockClosure
    side: #instance
    selector: #ensure:
    lowering: #tryFinally>
```

Suggested lowerings:

```text
#if
#ifNil
#ifNotNil
#booleanAnd
#booleanOr
#while
#timesRepeat
#toDo
#tryFinally
#tryIfCurtailed
#exceptionHandler
#unknown
```

These declarations are what allow flow-sensitive typing for ordinary Smalltalk control idioms.

---

## 13. Nil-flow metadata

Nil is still `UndefinedObject`, but GradT needs recognized refiners.

Example:

```smalltalk
GradTKernelNilFlow >> isNil
  <gradTRefinement:
    #Object
    side: #instance
    selector: #isNil
    true: #(receiver isExactly: #UndefinedObject)
    false: #(receiver excludes: #UndefinedObject)>
```

```smalltalk
GradTKernelNilFlow >> notNil
  <gradTRefinement:
    #Object
    side: #instance
    selector: #notNil
    true: #(receiver excludes: #UndefinedObject)
    false: #(receiver isExactly: #UndefinedObject)>
```

```smalltalk
GradTKernelNilFlow >> ifNilIfNotNil
  <gradTNilControl:
    #Object
    side: #instance
    selector: #ifNil:ifNotNil:
    nilBlock: 1
    nonNilBlock: 2>
```

Suggested normalized fields:

```text
GradTRefinementDeclaration
  targetMethod
  trueTypeMap
  falseTypeMap
  affectedExpression
  branchSemantics
```

The important rule is that `T | UndefinedObject` must remain a union internally even if the common callable protocol is initially treated as `Object`.

---

## 14. Reflection and invalidation metadata

Reflective operations should be annotated as unsafe or fact-invalidating.

Example:

```smalltalk
GradTKernelEffects >> instVarNamedPut
  <gradTEffect:
    #Object
    side: #instance
    selector: #instVarNamed:put:
    invalidates: #(receiver slotFacts receiver invariants)
    reflection: #slotWrite>
```

Literal slot reflection may be special-cased by the checker, but dynamic reflective access should invalidate assumptions.

Suggested normalized fields:

```text
GradTEffectDeclaration
  targetMethod
  mutatesReceiver
  mutatesArguments
  mutatesGlobals
  invalidatesFacts
  mayRunCode
  maySignal
  reflective
  purity
```

Effect values:

```text
#pure
#readsState
#writesReceiver
#writesArgument
#writesGlobal
#invalidatesSlotFacts
#invalidatesInvariants
#reflective
#unknown
```

---

## 15. Runtime boundary metadata

GradT needs to know where to emit generated contracts.

Example:

```smalltalk
GradTBoundaryPolicy >> packageBoundary
  <gradTBoundary:
    fromPackage: #MyTypedPackage
    toPackage: #MyUntypedPackage
    mode: #checked>
```

Method-level override:

```smalltalk
SomeClass >> dynamicEntryPoint: value
  <gradTBoundaryMode: #unchecked>
```

Suggested boundary modes:

```text
#unchecked
#staticOnly
#boundaryChecked
#publicChecked
#debugFull
```

Suggested normalized fields:

```text
GradTBoundaryDeclaration
  sourceRegion
  targetRegion
  mode
  generatedContracts
  blamePolicy
```

---

## 16. Blame metadata

For runtime contracts, GradT should record who is blamed on failure.

Default policy:

```text
precondition failure   -> caller
postcondition failure  -> callee
invariant failure      -> owner object / callee at stable boundary
type boundary failure  -> value provider
stale sidecar metadata -> declaration provider
```

Optional explicit pragma:

```smalltalk
<gradTBlamePolicy: #caller>
<gradTBlamePolicy: #callee>
<gradTBlamePolicy: #provider>
```

Suggested normalized fields:

```text
GradTBlameDeclaration
  contract
  defaultParty
  providerParty
  boundaryParty
  diagnosticTemplate
```

---

## 17. Registry requirements

The registry must support at least these queries:

```smalltalk
GradTRegistry current classDeclarationFor: aClass.
GradTRegistry current methodDeclarationFor: aCompiledMethod.
GradTRegistry current methodDeclarationForClass: aClass side: #instance selector: #add:.
GradTRegistry current slotDeclarationFor: #name in: aClass.
GradTRegistry current invariantsFor: aClass.
GradTRegistry current blockEffectsFor: aCompiledMethod argument: 1.
GradTRegistry current refinementsForSelector: #isNil in: Object.
GradTRegistry current effectsForSelector: #instVarNamed:put: in: Object.
```

It must also expose validation state:

```smalltalk
GradTRegistry current unresolvedDeclarations.
GradTRegistry current conflictingDeclarations.
GradTRegistry current staleDeclarations.
GradTRegistry current declarationsProvidedBy: aPackage.
```

---

## 18. Declaration validation

Before typechecking code, GradT should validate declarations.

Required checks:

```text
1. Target class exists.
2. Target selector exists, unless declaration is explicitly speculative.
3. Selector arity matches argument type count.
4. Slot exists, unless declaration is explicitly virtual/speculative.
5. Type names resolve.
6. Type variables are bound.
7. Source fingerprints match, if supplied.
8. Multiple declarations for the same target are compatible or explicitly overlaid.
9. Block argument indexes are valid.
10. Contract expressions parse.
11. Contract expressions mention valid parameters, slots, result, or old values.
12. Slot initialization policy is compatible with its declared type.
```

Declaration status values:

```text
#valid
#duplicate
#shadowed
#conflicting
#stale
#dangling
#unresolved
#speculative
#corrupt
```

---

## 19. Conflict semantics

If multiple declarations target the same class/method/slot:

```text
same declaration:
  harmless duplicate

compatible declaration:
  merge

incompatible declaration with no priority/overlay:
  conflict

incompatible declaration with explicit overlay:
  choose active overlay, report shadowing

stale declaration:
  do not silently apply

dangling declaration:
  keep visible, but inactive
```

GradT should not silently pick one incompatible declaration.

---

## 20. Minimal v0 metadata set

The first useful version does not need all metadata above.

A practical v0 should support:

```text
1. Type literal parser.
2. Class declarations.
3. Method signature declarations.
4. Slot declarations.
5. Initializer/constructor pragmas.
6. Preconditions, postconditions, invariants.
7. Block argument effects for common control/library methods.
8. Nil refinements for isNil/notNil/ifNil:/ifNotNil:.
9. Method/slot effect declarations for reflection.
10. Source fingerprint and stale-declaration reporting.
11. Registry validation and conflict reporting.
```

Everything else can be layered later.

---

## 21. Suggested core pragma families

A compact initial vocabulary:

```smalltalk
<gradTClass: typeParameters: superclass:>
<gradTAlias: type:>
<gradTMethod: side: selector: arguments: returns:>
<gradTParam: type:>
<gradTReturns:>
<gradTSlot: name: type: initialization: storage:>
<gradTSlotClass: storage: readEffect: writeEffect: writeImpliesInitialized:>
<gradTInitializer>
<gradTConstructor>
<gradTConstructorWithoutInitialize>
<gradTRequires:>
<gradTEnsures:>
<gradTInvariant: expression:>
<gradTOld: expression:>
<gradTRequiresSlots:>
<gradTEnsuresSlots:>
<gradTBlockArg: invocation: escape: execution: nonLocalReturn:>
<gradTControlForm: side: selector: lowering:>
<gradTRefinement: side: selector: true: false:>
<gradTEffect: side: selector: invalidates: reflection:>
<gradTBoundary: toPackage: mode:>
<gradTSourceHash:>
<gradTPriority:>
<gradTOverlay:>
```

The exact keyword spelling can change, but these are the metadata categories GradT needs before serious type analysis can begin.
