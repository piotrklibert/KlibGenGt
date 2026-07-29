# Gralk (Gradually Typed Smalltalk) Architecture and Semantics Specification

**Status:** Draft for implementation planning

**Intended audience:** Gralk maintainers, Pharo/GToolkit implementers, and
coding agents working on the project 

**Companion document:** *Gralk Pragma Metadata Draft*
[gralk-metadata-design.md](./gralk-metadata-design.md)

**Primary implementation language:** GToolkit distribution of Pharo Smalltalk

______________________________________________________________________

## Table of contents

1. [Purpose and relationship to the metadata specification](#1-purpose-and-relationship-to-the-metadata-specification)
1. [Normative language](#2-normative-language)
1. [Terminology](#3-terminology)
1. [Design goals](#4-design-goals)
1. [Non-goals](#5-non-goals)
1. [Architectural overview](#6-architectural-overview)
1. [Checking profiles and trust modes](#7-checking-profiles-and-trust-modes)
1. [Core semantic model](#8-core-semantic-model)
1. [Program model and stable identity](#9-program-model-and-stable-identity)
1. [Analysis transaction and pipeline](#10-analysis-transaction-and-pipeline)
1. [Control-flow intermediate representation](#11-control-flow-intermediate-representation)
1. [Flow-sensitive analysis](#12-flow-sensitive-analysis)
1. [Local type inference](#13-local-type-inference)
1. [Generic inference and constraint solving](#14-generic-inference-and-constraint-solving)
1. [Blocks, control effects, and non-local returns](#15-blocks-control-effects-and-non-local-returns)
1. [Method effects and aliasing](#16-method-effects-and-aliasing)
1. [Slots and definite initialization](#17-slots-and-definite-initialization)
1. [Contract core](#18-contract-core)
1. [Type/contract integration](#19-typecontract-integration)
1. [Runtime enforcement and instrumentation](#20-runtime-enforcement-and-instrumentation)
1. [Live-image consistency and invalidation](#21-live-image-consistency-and-invalidation)
1. [Diagnostics and tooling](#22-diagnostics-and-tooling)
1. [Caching, persistence, concurrency, and recovery](#23-caching-persistence-concurrency-and-recovery)
1. [Security and trust considerations](#24-security-and-trust-considerations)
1. [Proposed packages and principal classes](#25-proposed-packages-and-principal-classes)
1. [Public service APIs](#26-public-service-apis)
1. [Core algorithms](#27-core-algorithms)
1. [Testing and verification strategy](#28-testing-and-verification-strategy)
1. [Agent-ready work breakdown](#29-agent-ready-work-breakdown)
1. [Milestones](#30-milestones)
1. [End-to-end semantic scenarios](#31-end-to-end-semantic-scenarios)
1. [Open decisions and recommended defaults](#32-open-decisions-and-recommended-defaults)
1. [Definition of an end-to-end v0](#33-definition-of-an-end-to-end-v0)
1. [Implementation guidelines for coding agents](#34-implementation-guidelines-for-coding-agents)
1. [References and useful implementation sources](#35-references-and-useful-implementation-sources)
1. [Closing architectural rule](#36-closing-architectural-rule)

______________________________________________________________________

## 1. Purpose and relationship to the metadata specification

This document specifies the runtime, static-analysis, compiler, live-image, and tooling
components required for Gralk. It deliberately does **not** redefine the pragma
vocabulary, literal type syntax, declaration headers, registry keys, declaration
conflict rules, or annotation validation rules covered by the companion *GradT Pragma
Metadata Draft*.

The companion document answers:

> What declarations can be attached to Smalltalk code, and how are they serialized in
> pragmas?

This document answers:

> Once those declarations have been loaded and normalized, what do they mean, how are
> they analyzed, how are they enforced, how do they survive a live image, and how should
> the implementation be decomposed?

The pragma representation is an input format. All components specified here consume
normalized declaration objects through registry interfaces. No checker, contract
compiler, runtime monitor, or tool should interpret raw pragma arrays directly.

This specification is intended to be detailed enough to divide into agent-sized
implementation work packages. It therefore includes semantic rules, data structures,
algorithms, failure states, APIs, test criteria, sequencing constraints, and explicit
defaults for decisions that remain open.

______________________________________________________________________

## 2. Normative language

The words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** are normative.

- **MUST** identifies behavior required for interoperability between Gralk components.
- **SHOULD** identifies a strong default that may be changed for a documented reason.
- **MAY** identifies an optional capability.
- A **v0 requirement** is required before the first end-to-end checker/runtime
  prototype.
- A **later requirement** is architecturally anticipated but may be deferred.

______________________________________________________________________

## 3. Terminology

### 3.1 Program entities

- **Image entity:** A class, trait, compiled method, slot, global binding, package, or
  other live object that participates in program structure.
- **Declaration:** Normalized metadata derived from one or more pragmas.
- **Provider:** The package and method that supplied a declaration, especially for
  sidecar declarations.
- **Target:** The image entity described by a declaration.
- **Program snapshot:** A logically consistent view of relevant image entities and
  declaration versions used by one analysis transaction.
- **Ghost entity:** A placeholder representing a referenced but currently absent or
  broken entity.

### 3.2 Types and facts

- **Declared type:** A type explicitly supplied by metadata.
- **Inferred type:** A type computed from code and context.
- **Flow type:** The type known at one program point after applying control-flow
  refinements.
- **Base type:** The declared or initially inferred type to which flow refinements are
  relative.
- **Fact:** A proposition known at a program point, such as “local `x` excludes
  `UndefinedObject`” or “slot `name` is initialized.”
- **Tainted fact:** A fact that may have been invalidated by reflection, unknown
  effects, live mutation, or untrusted metadata.
- **Residual check:** A runtime contract emitted because the static analyzer could not
  prove an obligation.

### 3.3 Control and effects

- **Normal result:** A value returned to the immediately enclosing expression.
- **Abrupt completion:** Control flow that does not produce a normal result, including
  method return, non-local return, exception signaling, process termination, or
  non-returning primitive behavior.
- **Non-local return (NLR):** A `^` executed in a block that targets the lexically
  enclosing home method.
- **Control summary:** Metadata describing how a method invokes block arguments and how
  its result/control behavior should be modeled.
- **Effect summary:** Metadata or inferred information describing mutation, reflection,
  signaling, block invocation, or world-changing behavior.

### 3.4 Contracts

- **Flat contract:** A contract check that can decide immediately whether one value
  satisfies a predicate.
- **Higher-order contract:** A contract that must monitor future interactions with a
  value, usually by wrapping or instrumenting it.
- **Boundary:** A transition at which values or control move between regions with
  different trust or checking policies.
- **Blame:** The party identified as responsible for violating a contract.
- **Stable state:** A program point at which an object’s class invariant is required to
  hold.

______________________________________________________________________

## 4. Design goals

Gralk SHOULD satisfy the following goals.

### 4.1 Preserve Smalltalk execution and development semantics

Gralk is an optional/gradual layer over ordinary Smalltalk. It MUST NOT require a
separate runtime object model or a parallel source language for untyped code. Typed
source syntax may desugar to ordinary methods plus metadata, but the resulting methods
must remain ordinary compiled methods usable by existing tools.

The system MUST account for:

- live class and method replacement;
- first-class slots;
- open classes and extension methods;
- reflective access;
- blocks as ordinary objects and as control constructs;
- non-local returns;
- incomplete edits and temporarily broken images;
- code loaded in an order different from dependency order.

### 4.2 Keep annotations available to tools

Executable casts are not a sufficient representation of typing information. Type,
contract, block-effect, and slot information MUST remain queryable after compilation.
Browsers, inspectors, code completion, refactorings, debugger extensions, and external
agents must not have to reverse-engineer metadata from inserted casts.

### 4.3 Permit compilation in the presence of type errors

A type error MUST NOT, by default, make a method impossible to compile. Analysis is
advisory or boundary-enforcing depending on policy. The image must remain recoverable
even when its typed metadata is inconsistent.

A stricter project policy MAY reject deployment or package loading, but the interactive
compiler SHOULD still produce a method and a structured diagnostic.

### 4.4 Be explicit about uncertainty

Gralk MUST distinguish at least:

- valid and current analysis;
- stale analysis;
- incomplete analysis caused by missing entities;
- analysis containing unsafe assumptions;
- conflicting metadata;
- analysis failure caused by corrupted image structure;
- code deliberately excluded from checking.

It MUST NOT silently present stale or partial information as proved current fact.

### 4.5 Make runtime checking explain static assumptions

Generated contracts SHOULD correspond to explicit static obligations. A runtime failure
should report which assumption failed, where that assumption originated, what code
crossed the relevant boundary, and which party is blamed.

### 4.6 Support useful subsets before full precision

The architecture MUST permit incremental implementation. A useful early version should
provide nominal types, nil-sensitive flow analysis, simple locals, block/NLR checking
for common control constructs, slot initialization checks for ordinary slots, and
boundary contracts without requiring whole-image generic inference or perfect reflection
modeling.

______________________________________________________________________

## 5. Non-goals

The initial system is not required to provide:

1. A sound proof of all behavior in an arbitrarily mutated live image.
1. Whole-program inference of public method signatures.
1. Verification of arbitrary reflective code.
1. Automatic understanding of every custom slot class.
1. Full dependent/refinement typing of arbitrary contract predicates.
1. A theorem prover for numeric or heap invariants.
1. Transparent, zero-overhead deep contracts for arbitrary mutable object graphs.
1. A requirement that all Smalltalk code adopt Gralk.
1. A replacement for the ordinary debugger, compiler, or package system.
1. Automatic inference that an arbitrary block-taking method is equivalent to a known
   control form unless the proof is simple and validated.

______________________________________________________________________

## 6. Architectural overview

### 6.1 Major components

The system is divided into the following layers:

```text
Pragma-bearing methods
        |
        v
Metadata ingestion and normalized registry
        |
        +-----------------------+
        |                       |
        v                       v
Program model / resolver     Live dependency index
        |                       |
        v                       |
AST and control-flow lowering  |
        |                       |
        v                       |
Static analysis engine <-------+
  - type checking
  - flow analysis
  - local inference
  - generic constraints
  - block/control effects
  - slot initialization
        |
        +------------------------------+
        |                              |
        v                              v
Contract planner and compiler      Diagnostics/tooling index
        |
        v
Runtime enforcement backends
        |
        v
Structured violations and blame
```

### 6.2 Required dependency direction

To avoid circular dependencies, package dependencies SHOULD follow this shape:

```text
GradT-Core-Model
  <- GradT-Types-Core
  <- GradT-Contracts-Core
  <- GradT-Metadata

GradT-ProgramModel
  depends on Core-Model, Metadata

GradT-ControlFlow
  depends on ProgramModel, Core-Model

GradT-Analysis
  depends on Types-Core, Contracts-Core, ControlFlow, ProgramModel

GradT-TypeContracts
  depends on Types-Core and Contracts-Core

GradT-Contracts-Runtime
  depends on Contracts-Core, ProgramModel

GradT-Contracts-Compiler
  depends on Contracts-Core, Runtime, compiler/Reflectivity adapters

GradT-Live
  depends on Metadata, ProgramModel, Analysis, Runtime

GradT-Tools
  depends on public query interfaces from all of the above
```

`GradT-Contracts-Core` MUST NOT depend on the full typechecker. `GradT-Types-Core`
SHOULD NOT depend directly on the contract runtime. Translation between the two belongs
in `GradT-TypeContracts`.

### 6.3 Service boundaries

Every major component MUST expose an interface that can be replaced in tests. In
particular:

- image lookup must go through a program-model service;
- current declarations must go through a registry snapshot;
- source/AST access must go through a compiler adapter;
- live change observation must go through an event adapter;
- instrumentation must go through a backend interface;
- caches must not be consulted directly by semantic code.

This separation is essential for deterministic tests and for supporting multiple
Pharo/GToolkit versions.

______________________________________________________________________

## 7. Checking profiles and trust modes

A single “strict” Boolean is insufficient. Gralk SHOULD define orthogonal policy
dimensions, then provide named presets.

### 7.1 Static uncertainty policy

Recommended values:

- **advisory:** Unknown effects and missing declarations produce warnings; analysis
  retains optimistic facts where practical.
- **conservative:** Unknown effects invalidate affected facts; unsafe block/control
  behavior is an error.
- **closed-snapshot:** Treat the analyzed snapshot as closed except at explicit dynamic
  boundaries. Intended for tests, CI, and deployment validation.

### 7.2 Runtime enforcement policy

Recommended values:

- **off:** No generated runtime checks.
- **boundary:** Check crossings between typed and untyped or trusted and untrusted
  regions.
- **public:** Additionally enforce public method contracts and stable-state invariants.
- **debug:** Enable detailed checks at method, slot, and control boundaries.
- **sampled:** Enable selected checks probabilistically or through a tracing trigger.

### 7.3 Metadata trust policy

Recommended values:

- **trusted:** Accept valid current declarations as authoritative.
- **verified-sidecar:** Sidecar declarations require target fingerprint/version
  agreement.
- **untrusted:** Declarations may guide diagnostics but runtime checks protect every
  externally supplied fact.

### 7.4 Suggested presets

```text
#exploratory
  static uncertainty: advisory
  runtime: off or boundary
  metadata: trusted

#development
  static uncertainty: conservative
  runtime: boundary/public
  metadata: verified-sidecar

#ci
  static uncertainty: closed-snapshot
  runtime: boundary during tests
  metadata: verified-sidecar

#debugFull
  static uncertainty: conservative
  runtime: debug
  metadata: untrusted or verified-sidecar
```

The active profile MUST be recorded in every analysis result and runtime plan.

______________________________________________________________________

## 8. Core semantic model

### 8.1 Types are immutable value objects

All normalized types MUST be immutable and structurally comparable. They SHOULD be
interned or hash-consed after correctness is established, but semantic code MUST NOT
rely on object identity.

Minimum type classes:

```text
GradTType
GradTNominalType
GradTMetaType
GradTGenericType
GradTTypeVariable
GradTUnionType
GradTStructuralType
GradTBlockType
GradTSelfType
GradTSelfClassType
GradTDynamicType
GradTNeverType
GradTErrorType
GradTUnresolvedType
```

`GradTErrorType` propagates after a reported error to prevent cascades.
`GradTUnresolvedType` represents a named type whose binding is currently missing or
broken; it is not equivalent to dynamic typing.

### 8.2 Distinguish `Dynamic` from `Object`

Gralk MUST distinguish the gradual unknown type from the nominal class `Object`.

- **`Object`** means an instance in the `Object` nominal hierarchy. Only operations
  justified by its static protocol are directly permitted.
- **`Dynamic`** means that static checking defers to runtime behavior. Sends are
  permitted but may require runtime guards depending on policy.
- **`Never`** is the bottom type for expressions that cannot complete normally.
- **`UndefinedObject`** is an ordinary nominal class, not a magic null value outside the
  object model.

The name serialized by metadata may remain `Any` for compatibility, but the internal
model SHOULD use an unambiguous class name such as `GradTDynamicType`. The project must
make a one-time decision whether user-facing `Any` means dynamic or nominal top; it MUST
NOT mean both.

### 8.3 Subtyping, consistency, and assignability

Gradual typing requires three related but distinct relations.

#### 8.3.1 Subtyping

`S <: T` means every value satisfying `S` satisfies `T` with no dynamic check.

Examples:

```text
String <: Object
Never <: String
OrderedCollection<String> <: Collection<String>  (subject to generic inheritance mapping)
```

#### 8.3.2 Consistency

`S ~ T` means `S` and `T` are compatible when dynamic uncertainty is considered.
`Dynamic` is consistent with every type, but is not a subtype of every type.

#### 8.3.3 Assignment/check result

Checking an expression of type `S` against expected type `T` MUST return a result richer
than Boolean:

```text
#proved          no runtime check required
#consistent      accepted with a residual check/cast
#rejected        incompatible
#unresolved      cannot decide because the world is incomplete
```

The result SHOULD include an explanation and a proposed contract when `#consistent`.

### 8.4 Union types preserve alternatives

A union MUST remain a union even when its nominal least upper bound is a broad class.

For example:

```text
String | UndefinedObject
```

MUST NOT normalize to `Object`. It is assignable to `Object`, but retaining the
alternatives is required for branch refinement and precise runtime checks.

Union normalization SHOULD:

1. Flatten nested unions.
1. Remove duplicate alternatives.
1. Remove `Never` alternatives.
1. Absorb alternatives proven to be subtypes of another alternative only when doing so
   does not erase semantically relevant singleton/refinement information.
1. Apply a configurable complexity limit and widening strategy.

A practical default is a maximum of 8 alternatives before widening. Nil unions SHOULD be
exempt from aggressive widening because they are pervasive and highly useful.

### 8.5 Protocol available on a union

A send is statically safe on `A | B` only if every reachable alternative can accept the
selector with compatible argument and result contracts.

For `T | UndefinedObject`, this naturally exposes at least the common protocol inherited
from `Object`, including ordinary reflection and nil-testing messages provided there. No
artificial “nil whitelist” is required. Extension methods and overrides on
`UndefinedObject` participate through the ordinary method-resolution/program-model
layer.

The checker MUST still retain the union so that known predicates and control forms can
refine the receiver to `UndefinedObject` or the non-nil alternatives.

### 8.6 Nominal and structural types

Gralk SHOULD preserve Gradualtalk’s combination of nominal and structural typing.

- A nominal type is tied to a class binding and its inheritance relation.
- A structural type is a set of required message signatures.
- Nominal values MAY satisfy structural types through their visible protocol.
- Structural conformance MUST account for argument variance, return variance, block
  effects, and contracts, not just selector presence.

The initial implementation MAY support selector-and-arity structural checks first, but
it must mark such results as shallow/incomplete rather than fully proved signature
conformance.

### 8.7 Generic types

The initial generic model SHOULD be declaration-site invariant unless variance is
explicitly declared and proven safe.

Mutable collection types such as `OrderedCollection<T>` are invariant by default.
Read-only/protocol views MAY later be covariant.

Generic inheritance requires substitution maps. For example:

```text
OrderedCollection<E> <: SequenceableCollection<E>
SequenceableCollection<E> <: Collection<E>
```

The class declaration model must expose the map from subclass parameters to superclass
arguments.

### 8.8 `Self`, class-side, and metaclass types

Gralk MUST distinguish:

- the dynamic receiver type of an instance method (`Self`);
- the dynamic receiver class object on the class side (`SelfClass`);
- the instance type produced by a class object where relevant;
- concrete metaclass types.

A method returning `Self` preserves subclass-specific result typing. Constructors often
need a “new instance of receiver class” type, which should not be conflated with the
class object itself.

### 8.9 Method compatibility and overriding

An overriding method must be compatible with all inherited contracts visible at the
target class.

At minimum:

- argument types are contravariant;
- normal return types are covariant;
- preconditions cannot become stronger;
- postconditions cannot become weaker;
- required class invariants accumulate;
- noescape/synchronous block guarantees cannot be weakened;
- an override cannot introduce a possible NLR/escape behavior that violates the
  inherited block-control contract;
- declared effects cannot become stronger where callers rely on purity or fact
  preservation.

Where implication between arbitrary contracts cannot be proved, the checker SHOULD
report “unverified behavioral-subtyping obligation” rather than silently accepting or
rejecting it as a logical fact.

______________________________________________________________________

## 9. Program model and stable identity

### 9.1 Do not key semantic state only by object identity

Compiled methods, class objects, and slots can be replaced during live editing. Analysis
caches MUST NOT use their current object identity as the sole durable key.

Recommended keys:

```text
ClassKey
  environment/global namespace identity
  binding name
  optional package/module qualifier

MethodKey
  ClassKey
  side
  selector

SlotKey
  declaring ClassKey
  logical slot name

ProviderKey
  provider package
  provider ClassKey
  provider MethodKey
  pragma/declaration ordinal or stable declaration id
```

Each resolved key also carries the current live object identity and version stamp.

### 9.2 Binding identity versus name

A class rename may preserve conceptual identity while changing the global binding, or
may create a replacement class. The program model SHOULD expose both:

- binding identity/version;
- current name;
- class object identity;
- lineage or migration information when available.

Gralk must not assume that equal names imply the same class across analysis epochs.

### 9.3 Ghost entities

When a declaration references a missing class, method, or slot, the resolver SHOULD
create a ghost entity rather than discarding the dependency.

A ghost records:

```text
requested key
originating declarations/methods
expected entity kind
first-seen epoch
current resolution status
```

If the entity later appears, dependents can be reanalyzed automatically. This mirrors
the live-system dependency problem identified in the Gradualtalk work.

### 9.4 Program snapshots

Every analysis MUST run against a `GradTProgramSnapshot` containing:

- registry generation;
- class hierarchy generation;
- method dictionary generations for referenced classes;
- slot-layout generations;
- source/AST versions;
- active policy profile;
- optional package/load-state generation.

The snapshot need not copy the entire image. It is a set of versioned handles. Before
committing an analysis result, the service MUST verify that all hard dependencies still
match. Otherwise the result becomes stale and is discarded or stored only as historical
data.

### 9.5 Resolver behavior

The resolver MUST be able to answer without crashing when the image is partially broken:

```smalltalk
snapshot
  resolveClassKey: aClassKey;
  resolveMethodKey: aMethodKey;
  resolveSlotKey: aSlotKey;
  superclassOf: aClassHandle;
  visibleMethodsFor: aType;
  astFor: aMethodHandle;
  sourceMapFor: aMethodHandle.
```

Resolution returns a tagged result such as `resolved`, `missing`, `ambiguous`,
`corrupt`, or `unsupported`, with diagnostics.

______________________________________________________________________

## 10. Analysis transaction and pipeline

### 10.1 End-to-end method analysis

A method analysis SHOULD execute the following stages:

1. Capture a program and registry snapshot.
1. Resolve the method, class, slots, declarations, inherited signatures, aliases, and
   policies.
1. Validate semantic prerequisites not covered by declaration-shape validation.
1. Obtain the compiler AST and source map.
1. Build a normalized control-flow graph (CFG).
1. Seed parameter, receiver, slot, and temporary environments.
1. Run flow-sensitive type checking and local inference.
1. Solve generic and block constraints.
1. Validate returns, effects, contracts, slot initialization, and overrides.
1. Produce static facts, diagnostics, and residual obligations.
1. Ask the contract planner to produce an enforcement plan.
1. Record complete dependency edges.
1. Revalidate the snapshot.
1. Atomically publish the analysis and instrumentation plan.

### 10.2 Analysis output

`GradTMethodAnalysis` SHOULD contain:

```text
method key and resolved version
snapshot id/profile
status
base environment
CFG reference/version
node -> expression type map
node -> flow environment summaries
local inferred types
block summaries
slot initialization results
method effect summary
return summary
contract obligations
residual runtime plan
structured diagnostics
dependency set
performance/cost counters
```

### 10.3 Analysis status

Recommended statuses:

```text
#current
#currentWithWarnings
#unsafeAssumptions
#incomplete
#stale
#conflictingMetadata
#corruptProgramModel
#analysisFailed
#excluded
```

An internal exception MUST NOT automatically become “type error.” Unexpected analyzer
failures should be separately reported as tool defects.

### 10.4 Error recovery

The checker SHOULD continue after local errors by introducing `GradTErrorType` and
conservative effects. It should suppress derivative diagnostics where possible.

Example:

```text
Unknown selector on x
  -> report once
  -> expression gets ErrorType
  -> assignments and returns accepting ErrorType do not emit cascades
```

______________________________________________________________________

## 11. Control-flow intermediate representation

### 11.1 Why a CFG is required

Nested AST traversal is insufficient for:

- branch-sensitive nil/type refinements;
- early method and non-local returns;
- loops and fixed points;
- `ensure:` and `ifCurtailed:` cleanup;
- exception handlers;
- block invocation cardinality;
- merge points after control constructs;
- read-before-write analysis;
- precise invalidation of facts.

Gralk MUST lower method ASTs to a checker-specific CFG before serious flow analysis.

### 11.2 Minimum node kinds

```text
EntryNode
ExitNode
ExpressionNode
LiteralNode
LocalReadNode
LocalWriteNode
SlotReadNode
SlotWriteNode
SendNode
KnownControlSendNode
BlockLiteralNode
BlockInvokeNode
BranchNode
JoinNode
LoopHeaderNode
NormalReturnNode
NonLocalReturnNode
Signal/AbruptNode
EnsureEnterNode
EnsureExitNode
UnknownEffectNode
UnreachableNode
```

Nodes MUST retain source locations and original AST references.

### 11.3 Edges

Edges SHOULD be tagged:

```text
#normal
#true
#false
#loopBack
#methodReturn
#nonLocalReturn
#exception
#ensure
#curtailed
#unknownAbrupt
```

This prevents abrupt exits from being incorrectly joined into normal expression result
types.

### 11.4 Known control lowering

Selectors declared as control forms are lowered into explicit CFG shapes. Examples
include:

- `ifTrue:`, `ifFalse:`, `ifTrue:ifFalse:`;
- `ifNil:`, `ifNotNil:`, combined forms;
- `and:`, `or:`;
- `whileTrue:`, `whileFalse:`;
- `timesRepeat:`, `to:do:` and collection iteration summaries;
- `ensure:`, `ifCurtailed:`;
- selected exception-handling forms.

The metadata identifies semantics, but the builder MUST validate the actual send shape
and block arity. A malformed or dynamically ambiguous send falls back to ordinary send
analysis.

### 11.5 `ensure:` and `ifCurtailed:`

`[ body ] ensure: [ cleanup ]` must model cleanup on every completion path that the
Smalltalk semantics guarantee, including normal completion, method/NLR exit, and
exceptions. The cleanup block’s own abrupt completion can replace the original
completion and must be represented.

`ifCurtailed:` runs cleanup only when the protected block terminates abnormally. Normal
and curtailed successors must remain distinct until the appropriate merge.

### 11.6 Exception handling

A full exception type/effect system may be deferred, but the CFG MUST reserve abrupt
edges and handler regions from the beginning. Treating every signal as an ordinary
return would make later correction expensive.

### 11.7 Unreachable code

An expression following an unconditional `Never` result, method return, or NLR is
unreachable. The checker SHOULD:

- avoid using it to infer normal result types;
- optionally report unreachable code;
- still parse and locally validate it for tooling, under an “unreachable” context.

______________________________________________________________________

## 12. Flow-sensitive analysis

### 12.1 Flow environment

A `GradTFlowState` maps symbolic locations to facts.

Minimum location kinds:

```text
receiver
method parameter
method temporary
block parameter
captured temporary cell
self slot
stable expression path (later/limited)
```

Each entry SHOULD include:

```text
base type
current refined type
initialization state
assignment/version number
certainty/taint
origin of the fact
```

Global facts include current invariant state, unsafe/reflection taint, and known
reachability.

### 12.2 Stable locations

Refinement is safe only for expressions whose value cannot silently change between the
test and use.

v0 SHOULD refine:

- parameters and temporaries not reassigned;
- captured cells when block effects show no intervening write;
- `self` slots only while no effect capable of modifying them has occurred;
- the receiver itself;
- literal/global class bindings only under snapshot validity.

Arbitrary message-send expressions MUST NOT be refined as though repeated evaluation
returns the same value unless a purity/stability contract proves it.

### 12.3 Propositions

Conditions produce proposition pairs:

```text
true facts
false facts
```

Examples:

```text
x isNil
  true:  x = UndefinedObject
  false: x excludes UndefinedObject

x notNil
  true:  x excludes UndefinedObject
  false: x = UndefinedObject

x isKindOf: String
  true:  x intersects String
  false: x excludes String where representable
```

This is occurrence typing: predicates convey information about the type of an occurrence
in each branch.

### 12.4 Branch checking

For a branch:

```text
conditionState := check condition
trueState := apply condition.trueFacts to conditionState
falseState := apply condition.falseFacts to conditionState
trueOut := analyze true branch under trueState
falseOut := analyze false branch under falseState
out := join normal successors only
```

Abrupt branches do not contribute to the normal join. Thus:

```smalltalk
x isNil ifTrue: [ ^ self ].
x size
```

may refine `x` to non-nil after the branch.

### 12.5 Join operation

The flow-state join MUST be monotonic.

For types, use a precision-preserving union subject to widening policy. For
initialization states, use the lattice specified in the slot section. For taint, tainted
dominates trusted.

For a location assigned on one branch but not the other, the join combines the old and
assigned types and increments the location version appropriately.

### 12.6 Loops

Loops require a fixed point.

Recommended algorithm:

```text
entry := state before loop
header := entry
repeat up to limit:
  conditionResult := analyze condition under header
  bodyIn := apply true facts
  bodyOut := analyze body under bodyIn
  nextHeader := widen(join(entry, bodyOut))
  stop if equivalent(nextHeader, header)
  header := nextHeader
exitState := apply false facts to condition result under final header
```

The default iteration limit MAY be small (for example 3–5) if widening is deterministic.
Failure to reach a fixed point should produce a conservative widened state, not crash
analysis.

### 12.7 Fact invalidation

Facts are invalidated by:

- assignment to the location;
- a captured write from an invoked block;
- a send whose effect summary can mutate the location;
- reflective writes;
- unknown effects under conservative mode;
- live snapshot invalidation;
- aliasing that makes a write possible through another reference.

Invalidation should be targeted where possible. A literal reflective write to slot
`#name` need not invalidate every slot. A dynamic slot name may invalidate all receiver
slot facts.

### 12.8 Tainted facts

Advisory mode may retain a fact after an uncertain effect, but it MUST mark the fact
tainted. Uses of tainted facts should either:

- emit a warning;
- generate a residual contract;
- or be rejected under a stricter profile.

### 12.9 Nil safety semantics

Nil safety follows ordinary union and occurrence-typing rules:

1. A nullable value is represented as `T | UndefinedObject`.
1. The union is preserved, not collapsed to `Object`.
1. A send is accepted statically when all alternatives provide a compatible method.
1. `Object`-level predicates and reflection are naturally available where inherited by
   all alternatives.
1. Recognized predicates/control forms refine the alternatives in their branches.
1. No special non-object “null” semantics are introduced.

This design accommodates image-specific extensions on `UndefinedObject` through the
ordinary program model.

______________________________________________________________________

## 13. Local type inference

### 13.1 Scope

The first inference implementation SHOULD be intraprocedural and flow-sensitive. Public
method signatures, class type parameters, slot types, and externally visible contracts
remain declared metadata.

The checker MAY infer:

- method temporary types;
- block parameter types from expected block types and invocation sites;
- block normal result types;
- local generic arguments;
- local union refinements;
- a method’s observed return type for diagnostics and annotation suggestions.

It SHOULD NOT silently publish an inferred public signature as if it were a stable
declaration.

### 13.2 Bidirectional checking

Expression analysis SHOULD accept an optional expected type:

```smalltalk
checker typeOf: expression expected: expectedType in: flowState
```

Expected types improve inference for:

- block literals supplied to generic methods;
- empty collections;
- `nil` initializers;
- class-side constructors returning parameterized types;
- branch expressions;
- literal arrays used as typed data.

The result includes the actual type, generated constraints, effects, abrupt exits, and
residual obligations.

### 13.3 Temporary state

Each local should have a state distinct from its flow type:

```text
#unseen
#partial
#inferred
#declared
#error
```

A declared local has a fixed upper bound. An inferred local may widen under the selected
policy.

### 13.4 First assignment and widening

Recommended rules:

1. A non-partial first assignment establishes an inferred base type.
1. A later assignment that is a subtype preserves the base type.
1. A later incompatible but representable assignment widens to a union in permissive
   inference mode.
1. A declared local rejects assignments inconsistent with its declaration, except
   through explicit gradual consistency and a residual check.
1. Union growth is bounded by the configured complexity cap.

Example:

```smalltalk
x := 1.
x := 'one'.
```

may infer `SmallInteger | String` for a local in union-widening mode. A stricter “single
inferred type” policy may instead request an explicit annotation. The default SHOULD
favor unions because idiomatic Smalltalk often uses nil or sentinel initialization.

### 13.5 Partial types

Certain initializers do not provide enough information by themselves:

```smalltalk
result := nil.
items := OrderedCollection new.
map := Dictionary new.
```

Represent these as partial types:

```text
PartialNil
PartialGeneric(OrderedCollection, ElementVariable)
PartialGeneric(Dictionary, KeyVariable, ValueVariable)
```

Later assignments or sends solve them:

```smalltalk
result := self computeString.
```

produces `String | UndefinedObject`.

```smalltalk
items add: 1.
items add: 2.
```

constrains the element variable to an integer type.

A partial type unresolved at method exit SHOULD produce an annotation suggestion or
widen to a configured fallback (`Dynamic` by default in exploratory mode, error in
strict mode).

### 13.6 Use-before-assignment for locals

Smalltalk temporaries begin as `nil` at runtime, but Gralk may distinguish “implicitly
nil” from “programmer established a value.” For local nil safety, the default semantics
SHOULD be:

- an unassigned local has value type `UndefinedObject`;
- assigning a non-nil type widens or replaces according to partial-type rules;
- a stricter definite-local-assignment policy MAY report reads before any explicit
  assignment.

This policy should be independent of slot `lateinit` semantics.

### 13.7 Branch inference

A local assigned in both branches receives the join of the branch types. A local
assigned in only one branch joins the new value with the incoming value.

Example:

```smalltalk
flag
  ifTrue: [ x := 1 ]
  ifFalse: [ x := 'a' ].
```

infers `SmallInteger | String` after the branch.

### 13.8 Loop inference

Assignments inside a zero-or-more loop must join with the incoming type. One-or-more
invocation metadata may permit a stronger result.

Example:

```smalltalk
x := nil.
collection do: [ :each | x := each ].
```

normally leaves `x : Element | UndefinedObject`, because the collection may be empty.

### 13.9 Method return inference

Every normal method return, explicit or implicit, contributes to an observed result
union. NLR expressions contribute to their home method, not to the block’s normal
result.

The observed return type is used to:

- check a declared return type;
- suggest an annotation;
- detect inconsistent sidecar metadata;
- help contracts explain an actual returned value.

It MUST NOT automatically become the public signature without an explicit opt-in
promotion step.

### 13.10 Relevant MyPy implementation references

MyPy provides useful implementation precedents for local inference and partial types:

- [`mypy/checker.py`](https://github.com/python/mypy/blob/master/mypy/checker.py) —
  assignment checking, partial types, deferred passes, statement checking.
- [`mypy/binder.py`](https://github.com/python/mypy/blob/master/mypy/binder.py) —
  flow-sensitive bindings and branch frames.
- [Type inference and annotations](https://mypy.readthedocs.io/en/stable/type_inference_and_annotations.html)
  — user-facing inference policy and contextual inference.

Gralk should borrow the separation of binder/flow state from expression typing, but
adapt it to mutable captured variables, slots, and live image invalidation.

______________________________________________________________________

## 14. Generic inference and constraint solving

### 14.1 Constraint model

Generic calls should generate constraints rather than perform ad hoc substitution only.

Minimum constraint kinds:

```text
S <: α          lower-bound constraint
α <: T          upper-bound constraint
α = T           equality constraint
α consistent T  gradual consistency constraint
α excludes T    negative/refinement constraint, optional later
```

Each constraint records its source expression and method/signature origin for
diagnostics.

### 14.2 Call inference

For a send:

```smalltalk
receiver selector: argument
```

analysis should:

1. Resolve candidate method signatures for every receiver alternative.
1. Substitute receiver/class type arguments into each signature.
1. Introduce fresh variables for method type parameters.
1. Check actual arguments against formal types, collecting constraints.
1. Use the expected result type, if present, to add contextual constraints.
1. Solve variables.
1. Instantiate the normal result type, effects, contracts, and block summaries.
1. Join compatible candidate results or diagnose ambiguous/incompatible alternatives.

### 14.3 Solver behavior

A practical solver SHOULD:

- collect lower and upper bounds per variable;
- compute a least solution satisfying lower bounds and upper constraints;
- preserve unions where useful;
- prefer declared nominal bounds over `Dynamic`;
- report unsatisfied and underconstrained variables separately;
- avoid recursive expansion through cycle detection;
- expose a trace of how each solution was derived.

For mutable generic containers, observed writes add lower bounds and reads use the
solved element type.

### 14.4 Collection examples

Given:

```text
OrderedCollection<E> >> add: E -> E
```

and:

```smalltalk
xs := OrderedCollection new.
xs add: 1.
xs add: 'a'.
```

constraints are approximately:

```text
SmallInteger <: E
String <: E
```

so the local solution may be `SmallInteger | String`, subject to widening policy.

Given:

```text
Collection<E> >> collect: Block<E -> R> -> ReceiverCollection<R>
```

block parameter type is contextually `E`; the block’s normal result constrains `R`; the
result retains the receiver’s collection family where the declared method semantics
justify it.

### 14.5 Receiver-family types

Collection protocols often preserve a receiver-specific family rather than literally
returning the declaring class. The semantic model SHOULD support an abstract constructor
such as:

```text
ReceiverFamily<T>
```

Resolution maps it based on the concrete receiver and the actual method behavior. This
mapping belongs in class/method semantic declarations, not a hard-coded assumption that
every `collect:` preserves exact class.

### 14.6 Empty collections and delayed solving

An empty generic constructor creates fresh unsolved variables. The variables remain
scoped to the local value/flow analysis and should not leak globally.

If the value escapes before a useful constraint is found, policy options are:

- require an expected/declared type;
- freeze remaining variables as `Dynamic` with a warning;
- generate a polymorphic local value where supported.

v0 SHOULD choose the first or second option and avoid implicit local generalization of
mutable values.

### 14.7 Variance

The solver MUST respect declaration-site variance. Until variance metadata is
implemented, assume invariance. Block argument and result positions still use ordinary
function variance during signature conformance.

### 14.8 Solver reference

MyPy’s generic inference implementation is a useful source of concrete algorithms:

- [`mypy/infer.py`](https://github.com/python/mypy/blob/master/mypy/infer.py)
- call checking and contextual inference in
  [`mypy/checkexpr.py`](https://github.com/python/mypy/blob/master/mypy/checkexpr.py)

Gralk’s solver can initially be smaller, but constraints should be represented
explicitly so later features do not require replacing ad hoc code.

______________________________________________________________________

## 15. Blocks, control effects, and non-local returns

### 15.1 Block types are not sufficient by themselves

A block signature such as `Block<A -> R>` describes normal arguments and normal result
only. Smalltalk analysis also needs to know:

- whether the block is invoked;
- minimum and maximum invocation count;
- whether invocation is synchronous;
- whether the block escapes the dynamic extent of the call;
- whether it may run in another process;
- whether an NLR is permitted and meaningful;
- which captured cells and slots it reads or writes;
- which abrupt exits it can trigger.

These properties are modeled in a `GradTBlockSummary` and in the consuming method’s
block-argument control summary.

### 15.2 Block summary

Recommended fields:

```text
block AST/source identity
argument types
normal result type
normal completion possible
non-local return targets and value types
exception/signal effects
captured local reads
captured local writes
self slot reads/writes
may mutate self
may invoke unknown code
creation environment version
escape classification
```

### 15.3 `Never` and abrupt completion

A block consisting of `[ ^ value ]` has normal result `Never`. The value type belongs to
an NLR effect targeting the lexically enclosing method.

A mixed block:

```smalltalk
[ :each |
  each isNil ifTrue: [ ^ self ].
  each size ]
```

has:

```text
normal result: Integer
NLR effect: return Self from home method
```

The NLR type MUST NOT be unioned into the normal block result.

This follows the precedent of Strongtalk’s bottom-like “DoesntMatter” treatment for
expressions that do not yield normally. See
[Strongtalk: Typechecking Smalltalk in a Production Environment](https://bracha.org/oopsla93.pdf).

### 15.4 Invocation cardinality

Internally normalize invocation behavior to an interval plus conditions:

```text
minimum invocations: 0 or 1
maximum invocations: 0, 1, many, unknown
path condition: optional
```

Convenience names map to intervals:

```text
never       [0,0]
zeroOrOne   [0,1]
exactlyOnce [1,1]
zeroOrMore  [0,many]
oneOrMore   [1,many]
unknown     [0,unknown]
```

Conditional forms additionally associate invocation with a receiver/condition
proposition.

### 15.5 Captured-variable propagation

For a block that writes captured location `x`:

- **exactly once, synchronous, noescape:** propagate the block’s outgoing state.
- **zero or one:** join incoming and outgoing state.
- **one or more:** use a loop fixed point; at least one execution may eliminate some
  incoming alternatives.
- **zero or more:** loop fixed point joining incoming state.
- **unknown or escaping:** do not assume the block ran; invalidate or taint affected
  locations according to policy.
- **asynchronous/other process:** never use the write as an immediate flow refinement;
  mark concurrency/escape effects.

Captured temporaries must be modeled as shared cells, not copied values.

### 15.6 Noescape and synchronous guarantees

A method summary promising `noescape` and `synchronous` allows the caller to reason
about NLR and captured writes. These promises are behavioral contracts of the callee.

An override MUST NOT store or asynchronously invoke a block if the inherited signature
promises noescape synchronous behavior.

### 15.7 Non-local return validation

An NLR in a block is accepted statically only if all possible consumers of that block
guarantee an execution context in which the home method remains active, unless the
programmer uses an explicit unsafe escape.

Rules:

1. A block immediately used by a recognized synchronous noescape control form may
   contain an NLR.
1. A block passed to a method with matching block-effect metadata may contain an NLR.
1. A block passed to an unknown, escaping, delayed, or asynchronous consumer produces an
   error in conservative mode and a warning/runtime-risk marker in advisory mode.
1. A returned, stored, or globally published block containing an NLR is unsafe unless a
   specialized contract proves invocation remains within the home activation.
1. Cross-process execution of an NLR block is forbidden/unsafe.

At runtime, an invalid late NLR can produce `BlockCannotReturn`; Gralk’s goal is to
identify likely sites before execution and attach a precise explanation.

Useful background:

- [Context and BlockClosure implementation](https://clementbera.wordpress.com/2015/01/21/context-and-blockclosure-implementation/)
- [About blocks, variables and blocks](https://thepharo.dev/2020/06/19/about-blocks-variables-and-blocks/)
- [Deep Into Pharo: Handling Non-Local Returns](https://eng.libretexts.org/Bookshelves/Computer_Science/Programming_Languages/Book%3A_Deep_into_Pharo_%28Bergel_Cassou_Ducasse_and_Laval%29/12%3A_Handling_Exceptions/12.03%3A_Handling_Non-Local_Returns)

### 15.8 Unknown block-taking methods

Without a declaration or soundly inferred summary, use the conservative summary:

```text
invocation: unknown
escape: may escape
execution: unknown
process: unknown
NLR: unsafe
captured writes: may occur at unknown time
```

This does not make the call untypeable. It prevents unsound flow propagation and may
require a residual control contract or diagnostic.

### 15.9 Summary inference for simple methods

Later, Gralk MAY infer block summaries for simple methods by analyzing block uses:

```smalltalk
evaluateOnce: aBlock
  ^ aBlock value
```

can plausibly infer exactly-once, synchronous, noescape, barring reflective publication
or alternate paths.

Inference MUST be validated against all paths and must remain invalidatable when the
method changes. Manually declared summaries remain preferable for core libraries in v0.

### 15.10 Control-form lowering versus ordinary sends

The checker should not depend on whether the VM/compiler currently inlines a selector.
It uses semantic control declarations and AST shape. This permits the same analysis for
VM-recognized conditionals and library-level constructs.

The Opal compiler work is relevant background on Pharo control-flow compilation:
[Opal: A New Compiler Architecture for Pharo](https://inria.hal.science/hal-00862411/document).

______________________________________________________________________

## 16. Method effects and aliasing

### 16.1 Purpose

Flow facts, slot initialization, contract purity, and live invalidation all require an
effect model. The first model should be useful rather than exhaustive.

### 16.2 Effect summary

A method effect summary SHOULD include:

```text
reads receiver state
writes receiver state
receiver slots definitely/maybe written
reads/writes argument state by index
reads/writes globals/class variables
allocates
signals/may complete abruptly
invokes block arguments and their control summaries
performs reflection
changes class/method/slot structure
spawns or communicates with another process
calls unknown code
purity classification
```

### 16.3 Effect classes

Suggested lattice:

```text
#pure
#readOnly
#localMutation
#receiverMutation
#argumentMutation
#globalMutation
#reflectiveMutation
#worldMutation
#unknown
```

Specific sets are more useful than the coarse class, but the class allows fast
conservative decisions.

### 16.4 Unknown sends

Under conservative mode, an unknown send may:

- mutate the receiver;
- mutate mutable arguments;
- invoke passed blocks according to unknown policy;
- signal;
- invalidate facts about aliased state.

It need not invalidate unrelated local values that cannot be aliased.

Advisory mode may retain facts with taint and residual checks.

### 16.5 Alias precision

v0 SHOULD use simple alias classes:

- immutable literal/value;
- local fresh allocation not escaped;
- receiver (`self`);
- argument;
- global/shared;
- unknown.

A later points-to analysis MAY improve this. The initial implementation must not pretend
arbitrary object identity is immutable.

### 16.6 Reflection

Reflection is treated as an explicit effect boundary, not as a reason to disable
checking.

Examples:

- literal `instVarNamed: #name put:` can map to a precise slot write;
- dynamic slot name invalidates receiver slot facts;
- `perform:` with literal selector can resolve normally where arity is known;
- dynamic `perform:` produces an unknown send effect and a marked unsafe site;
- class/method installation produces world mutation and invalidates relevant program
  snapshots.

Every reflective/unsafe site SHOULD be queryable by tooling.

### 16.7 Purity

Contract expressions and type refinements need a stricter notion than “appears
read-only.” Purity classes SHOULD include:

```text
#totalPure       deterministic, no mutation, no signaling/nontermination assumed
#pureMayFail     no mutation but may signal or diverge
#readOnly        reads mutable state
#impure
#unknown
```

Only facts derived from trusted predicates with declared static meaning should
participate in occurrence typing. Arbitrary user predicates are runtime contracts unless
a refinement declaration explains them.

______________________________________________________________________

## 17. Slots and definite initialization

### 17.1 Principle

Gralk MUST NOT assume that every Pharo slot is a raw index into object memory. Slots are
first-class metaobjects and may customize read/write behavior. The checker therefore
consumes a semantic slot descriptor produced by an adapter layer.

Relevant background:

- [Flexible Object Layouts: Enabling Lightweight Language Extensions by Intercepting Slot Access](https://doi.org/10.1145/2076021.2048138)
- [Typed slots for Pharo](https://medium.com/@juliendelplanque/typed-slots-for-pharo-98ba5d5aafbe)

### 17.2 Slot adapter

`GradTSlotAdapter` maps a resolved Pharo slot and declarations to:

```text
logical slot key
read type
write type
storage category
read effect
write effect
physical uninitialized representation if known
write-implies-initialized flag
read-before-write policy
supports static definite-assignment flag
runtime guard strategy
```

The checker MUST NOT invoke arbitrary runtime `read:`/`write:to:` methods to discover
semantics.

### 17.3 Storage categories

#### 17.3.1 Ordinary stored slot

Direct per-instance storage with predictable read/write semantics. Supports full
definite-initialization analysis.

#### 17.3.2 Decorated stored slot

Per-instance storage with checks, notifications, coercion, or other behavior. Supports
definite assignment only if its semantic descriptor promises that a successful write
establishes initialization and specifies read behavior.

#### 17.3.3 Defaulted/lazy slot

Reading before an explicit write may produce or install a default. The slot’s contract
determines whether it is considered initialized on read.

#### 17.3.4 Computed/virtual slot

No ordinary stored value is assumed. Type checking may use declared read/write
contracts, but classic definite assignment is not applicable.

#### 17.3.5 External/unknown slot

Gralk cannot model storage behavior. It may insert runtime read/write contracts but MUST
NOT claim a static read-before-write proof.

### 17.4 Initialization state lattice

Initialization is separate from value type.

Recommended lattice:

```text
             Unknown
            /       \
MaybeInitialized   (implementation may keep taint separately)
        /       \
Initialized   Uninitialized
```

Operationally:

```text
join(Initialized, Initialized) = Initialized
join(Uninitialized, Uninitialized) = Uninitialized
join(Initialized, Uninitialized) = MaybeInitialized
join(MaybeInitialized, anything definite) = MaybeInitialized
join(Unknown, anything) = Unknown
```

A separate taint bit SHOULD record uncertainty caused by effects.

### 17.5 Slot policies

The metadata spec defines policy names. Their semantic obligations are:

- **nullable:** the slot always has a readable value, possibly `UndefinedObject`; no
  read-before-write failure.
- **required:** constructors/initializers must establish it before the object reaches
  stable externally visible state; normal methods may assume it only when construction
  contracts are trusted.
- **lateinit:** reads require proof of initialization or a runtime guard. Initially
  restrict to non-nil declared types so physical `nil` can be the sentinel.
- **defaulted:** slot semantics guarantee the declared read type before explicit write.
- **computed:** no definite-assignment obligation.
- **external/unknown:** static initialization proof unavailable.

### 17.6 Method entry states

For ordinary methods on a stable object:

- required slots begin `Initialized` if the class construction invariant is trusted;
- nullable/defaulted slots begin readable;
- lateinit slots begin `Unknown` unless a stronger receiver/object-state contract is
  available;
- computed/external slots use their semantic descriptors.

For initializers/constructors:

- own required/lateinit slots begin `Uninitialized` unless already established by a
  lower-level constructor contract;
- inherited state is controlled by superclass initialization contracts;
- nullable slots begin with `UndefinedObject` as a valid value;
- object invariant begins dirty/not established.

### 17.7 Reads and writes

A slot write:

1. checks the expression against the slot write type;
1. applies write effects/contracts;
1. marks the slot initialized only if the descriptor says a successful write does so;
1. marks relevant invariants dirty;
1. emits residual checks where static proof is insufficient.

A slot read:

1. checks initialization policy/state;
1. emits a diagnostic or runtime guard if necessary;
1. applies read effects;
1. returns the descriptor’s read type, refined by known facts.

### 17.8 `lateinit` runtime behavior

For a non-null stored slot using physical `nil` as sentinel, the runtime guard should
signal a dedicated `GradTUninitializedSlotViolation` carrying:

- receiver/class;
- logical slot;
- read source location;
- initialization contract/provider;
- last known writes if tracing is enabled.

Nullable-lateinit requires a distinct sentinel or slot-specific state and SHOULD be
deferred.

### 17.9 Constructors and initializers

Smalltalk construction is conventional. v0 SHOULD rely on explicit
initializer/constructor declarations rather than attempting whole-image discovery.

Rules:

1. An initializer must establish all required own slots named by its contract before
   normal completion.
1. A trusted `super initialize` summary establishes inherited required slots.
1. A constructor returning a newly allocated instance must establish the target class’s
   construction invariant or delegate to a trusted initializer/constructor.
1. A constructor bypassing `initialize` must explicitly account for all required slots.
1. Returning or publishing `self` before required slots are established is an
   object-escape hazard.

### 17.10 Object escape during construction

The analysis SHOULD detect obvious escapes:

- storing `self` in a global/class variable;
- returning `self` from an initializer before completion;
- passing `self` to unknown code;
- registering callbacks capturing `self`;
- publishing into an argument object.

Conservative mode reports an error if required slots/invariant are not established.
Advisory mode marks construction unsafe and inserts an invariant/slot check at the
boundary.

### 17.11 Hierarchical initialization

Initialization state is tracked per declaring class. After a trusted superclass
initializer returns, inherited required slots are considered initialized, but the
subclass’s own slots are unaffected.

A subclass invariant includes inherited invariants. It is established only after all
relevant initializer phases complete.

### 17.12 Reflection and slot state

Precise reflective writes should update the corresponding slot state. Imprecise writes
invalidate or taint all potentially targeted slots. Reflective reads require the
appropriate read contract but do not by themselves establish initialization.

### 17.13 Unknown/custom slots

Unknown slots do not block all typechecking. Gralk may still:

- enforce declared read/write types dynamically;
- expose the slot in tooling;
- record that definite initialization is unproved;
- require a runtime object invariant at stable boundaries.

This capability-based approach is preferable to hard-coding every slot subclass.

______________________________________________________________________

## 18. Contract core

### 18.1 Role

The contract subsystem is useful independently of the complete typechecker. It provides:

- executable preconditions, postconditions, and invariants;
- explicit stable-state checking;
- higher-order monitors;
- structured blame and violations;
- a common representation for type-generated runtime guards;
- static facts for the subset of contracts the analyzer recognizes;
- profiling and selective enforcement.

### 18.2 Contract IR

A contract MUST be more than an arbitrary block. Recommended hierarchy:

```text
GradTContract
GradTFlatContract
GradTTypeContract
GradTAndContract
GradTOrContract
GradTNotContract
GradTImplicationContract
GradTMethodContract
GradTBlockContract
GradTCollectionContract
GradTStructuralContract
GradTSlotContract
GradTInvariantContract
GradTOldValueCapture
GradTUnsafePredicateContract
```

Each object SHOULD expose:

```text
subject/bound variables
source/provider
runtime evaluator or monitor factory
static proposition, if any
purity and cost
blame rule
hard dependencies
human-readable rendering
```

### 18.3 Contract expression language

The default contract language SHOULD be a validated AST, not arbitrary Smalltalk
evaluation.

It should support initially:

- literals;
- parameters, receiver, result, and named old values;
- slot reads through resolved slot keys;
- boolean combinations;
- equality/identity;
- numeric/order predicates where declared pure;
- `isNil`, `notNil`, `isKindOf:`, `respondsTo:`;
- selected pure message sends;
- collection quantification only when explicitly requested and costed.

An explicit unsafe form MAY embed arbitrary Smalltalk behavior, but must be labeled
impure/untrusted, excluded from static promotion, and guarded against recursive contract
invocation.

### 18.4 Flat versus higher-order contracts

A flat contract checks immediately. A higher-order contract monitors later interactions.

Examples:

- `String` nominal check: flat.
- `String | UndefinedObject`: flat disjunction.
- `Block<Integer -> String>`: higher-order; calls must check argument/result and control
  effects.
- mutable `Collection<Integer>`: either expensive deep flat traversal or a
  higher-order/use-site monitor.
- structural object protocol: shallow selector check is flat-ish; signature/behavior
  guarantees require monitored sends or typed use-site checks.

Racket’s contract hierarchy and chaperone model provide useful precedents:

- [Racket contract reference](https://docs.racket-lang.org/reference/contracts.html)
- [Chaperones and impersonators](https://docs.racket-lang.org/reference/chaperones.html)
- [Chaperones and Impersonators: Run-time Support for Reasonable Interposition](https://www2.ccs.neu.edu/racket/pubs/oopsla12-sthff.pdf)

### 18.5 Preconditions and postconditions

For a method call:

- the caller is responsible for preconditions;
- the callee is responsible for normal-result postconditions;
- exceptional/NLR postconditions, if supported, are separate;
- provider metadata may be blamed when a sidecar declaration is stale or false.

Postconditions can reference `result` and captured `old` values. Old expressions are
evaluated exactly once before method execution, under their own purity/error policy.

### 18.6 Class invariants and stable states

Class invariants SHOULD be checked at stable boundaries, not after every internal
operation.

Default stable-state policy:

1. after successful construction/initialization;
1. on entry to externally visible checked instance methods;
1. on normal exit from those methods;
1. before an object crosses from typed/trusted to untyped/untrusted code;
1. after return from untrusted code if it may have mutated the object;
1. at explicit programmer-requested checkpoints.

Private/internal helper calls within the same checked activation need not recheck
invariants unless debug-full mode requests it.

Because Smalltalk lacks enforced visibility, “externally visible” is a Gralk policy
derived from package boundaries, method protocol conventions, explicit metadata, or
instrumentation context.

### 18.7 Invariant dirty tracking

Runtime and static analysis SHOULD track whether an object’s invariant is known clean,
dirty, or unknown during a checked activation.

- writes to invariant-dependent slots mark it dirty;
- a successful invariant check marks it clean;
- unknown reflective mutation marks it unknown;
- method exit requires clean under public/debug policies.

This can avoid repeated checks after every write.

### 18.8 Contract inheritance

Effective contracts follow Design by Contract principles:

```text
effective precondition = inherited precondition OR new precondition
effective postcondition = inherited postcondition AND new postcondition
effective invariant = inherited invariant AND class invariant
```

Operationally, a subtype accepts at least what its supertype accepted and guarantees at
least what it guaranteed. Where logical implication cannot be decided, Gralk records an
unverified obligation and may retain runtime checks.

See
[Eiffel: Design by Contract and Assertions](https://www.eiffel.org/doc/solutions/Design_by_Contract_and_Assertions).

### 18.9 Contract static meaning

A contract may expose a static effect such as:

```text
assume x has type T
refine x on true/false branch
slot s is initialized
object invariant is established
facts about receiver are invalidated
method does not return normally
```

Only recognized, trusted contract classes provide static meaning. Running an arbitrary
predicate successfully does not automatically teach the static checker a theorem.

### 18.10 Contract failures

A contract evaluator can itself fail through signaling, nontermination, reflection, or
malformed metadata. Distinguish:

- the subject violates the contract;
- contract evaluation failed;
- contract metadata is stale;
- the contract provider supplied an invalid contract;
- the runtime could not safely instrument the boundary.

These must not all appear as the same assertion failure.

### 18.11 Reentrancy and recursion

Contract execution may invoke checked methods. Runtime state MUST prevent accidental
infinite recursion, especially for invariants reading slots through instrumented
accessors.

Recommended mechanism:

```text
per-process contract stack
  contract id
  subject identity
  phase (pre/post/invariant/read/write)
```

Re-entering the same invariant on the same object MAY be suppressed or treated as a
contract-cycle diagnostic depending on mode.

### 18.12 Contract profiling

Every check SHOULD optionally record:

- count;
- total and maximum time;
- allocations/wrappers;
- success/failure count;
- source and generated obligation;
- whether later static analysis could erase it.

Racket’s [contract profiler](https://docs.racket-lang.org/contract-profile/index.html)
is a useful model for exposing contract cost rather than guessing.

______________________________________________________________________

## 19. Type/contract integration

### 19.1 Separate translation component

`GradT-TypeContracts` translates between type obligations and contract IR. Neither core
type algebra nor core contracts should embed the other’s implementation details.

### 19.2 Type to contract

Every runtime-checkable type SHOULD support a translation request:

```smalltalk
typeContractFactory
  contractFor: aType
  position: aBlamePosition
  depth: aDepthPolicy
  context: aTranslationContext
```

Examples:

```text
String
  -> nominal class contract

String | UndefinedObject
  -> disjunction of nominal contracts

OrderedCollection<Integer>
  -> outer nominal check plus configured element strategy

Block<Integer -> String>
  -> higher-order block monitor

Structural protocol
  -> shallow responds-to checks and/or monitored sends

Dynamic
  -> no immediate restriction, but boundary records dynamic origin
```

### 19.3 Contract depth policies

Recommended policies:

- **shallow:** check only the outer class/protocol shape.
- **eagerDeep:** traverse current reachable contents immediately; expensive and
  vulnerable to mutation after checking.
- **lazyInterposed:** wrap/chaperone future reads and writes.
- **useSite:** instrument operations performed by typed code rather than wrap the object
  globally.
- **transient:** insert checks at elimination/use sites.
- **erased:** no runtime check because proof is current and trusted.

The contract planner selects a policy based on mutability, boundary direction, runtime
mode, and cost budget.

### 19.4 Mutable collections

A one-time deep traversal does not guarantee that a mutable collection remains typed.
The planner SHOULD prefer:

- boundary wrappers/interposition when identity semantics permit;
- use-site checks on `add:`, `at:`, iteration, and related protocol;
- ownership/confinement restrictions;
- or explicit shallow guarantees with honest diagnostics.

“Checked once” must not be described as a lasting deep guarantee for mutable state.

### 19.5 Blocks

A block contract may check:

- argument types on each invocation;
- normal result type;
- NLR/control policy;
- invocation process/dynamic extent where observable;
- captured/object effects only where instrumentation can monitor them.

Wrapping a block can change identity and reflective behavior. The runtime plan MUST
record this semantic cost and MAY prefer call-site instrumentation for core control
blocks.

### 19.6 Contract to static fact

The static analyzer may promote a manual contract to a fact when:

1. the contract class has a defined static interpretation;
1. referenced locations are stable;
1. the declaration is current and trusted;
1. required purity/effect assumptions hold.

Examples:

```text
requires x notNil
  -> x excludes UndefinedObject at method entry

ensures result isKindOf: String
  -> declared/observed result constrained to String

ensures slot #name initialized
  -> caller flow state updates after a trusted synchronous send
```

Unknown contracts remain runtime-only.

### 19.7 Residualization and erasure

For every contract obligation, the analyzer classifies it:

```text
#proved          erase
#partiallyProved simplify and retain residual
#unproved        retain
#tainted         retain and mark unsafe source
#contradicted    static diagnostic; runtime check optional for continued execution
#unrepresentable cannot generate runtime contract; diagnostic
```

This makes “manual contract today, type proof tomorrow” a normal optimization rather
than a migration rewrite.

### 19.8 Boundary blame

Blame records SHOULD distinguish at least:

- value provider;
- value consumer;
- caller;
- callee;
- declaration provider;
- world mutation that invalidated a prior proof;
- instrumentation/runtime subsystem failure.

A runtime violation must include both dynamic stack context and static declaration/proof
origin.

______________________________________________________________________

## 20. Runtime enforcement and instrumentation

### 20.1 Enforcement plan

Static analysis emits a declarative `GradTEnforcementPlan`, not bytecode changes
directly.

Recommended entries:

```text
method entry precondition
method exit postcondition
old-value capture
invariant entry/exit
argument/result type boundary
slot read/write guard
block invocation wrapper/check
control/NLR guard
untrusted-call revalidation
```

Each entry carries source mapping, cost, activation policy, and blame.

### 20.2 Cast/check placement strategies

Gradualtalk research compares three broad strategies:

1. **Caller/call-site checking:** checks before sends and at uses.
1. **Callee/execution checking:** checks on method entry/exit.
1. **Hybrid:** combine or duplicate paths to reduce checks while retaining modularity.

Gralk SHOULD make placement a planner policy rather than hard-code one strategy. The
initial implementation should favor clear modular boundaries and diagnostics over
speculative micro-optimization.

Useful reference:
[Gradualtalk: Cast Insertion Strategies for Gradually-Typed Smalltalk](https://www.johanfabry.be/assets/allendeAl-dls2013.pdf).

### 20.3 Backends

#### 20.3.1 Compiler/AST lowering backend

Insert checks while compiling typed/desugared methods.

Advantages:

- direct source mapping;
- efficient generated code;
- no extra method lookup layer;
- suitable long-term backend.

Costs:

- deeper compiler coupling;
- must preserve normal tooling/source views;
- recompilation required when plans change.

#### 20.3.2 Reflectivity/MetaLink backend

Attach instrumentation to AST nodes/method events.

Advantages:

- natural for optional dynamic/debug instrumentation;
- supports fine-grained entry, return, send, and slot sites;
- easier experimentation.

Costs:

- version-sensitive integration;
- reflective recompilation/activation overhead;
- metadata and source mapping must be carefully retained.

Background:
[Reflectivity: Sub-method, partial behavioral reflection for Pharo](https://inria.hal.science/hal-02480136v1/document).

#### 20.3.3 Wrapper/renamed-original backend

Install a wrapper method that checks contracts and invokes an original implementation
stored under another selector or method object.

Advantages:

- straightforward prototype;
- independent of deep compiler hooks.

Costs:

- method dictionary pollution;
- identity/senders/implementors/tooling complications;
- `super` and reflective semantics require care;
- live replacement is harder.

This backend MAY be used for a proof of concept but SHOULD NOT be the sole long-term
representation.

### 20.4 Recommended implementation sequence

1. Build a backend-neutral enforcement plan and interpreter for tests.
1. Implement method entry/exit and invariant checks with Reflectivity or a minimal
   compiler hook.
1. Add slot read/write instrumentation for ordinary slots.
1. Add block checks at declared boundaries.
1. Optimize common flat nominal/nil checks into compiler-generated code.
1. Add hybrid placement only after profiling.

### 20.5 Critical system code

Instrumentation of the compiler, debugger, exception machinery, contract runtime, and
Gralk itself can make recovery impossible. The runtime MUST support exclusion zones and
an emergency disable path.

Recommended defaults:

- Gralk runtime and recovery tools are uninstrumented;
- critical packages require explicit opt-in;
- instrumentation installation is transactional;
- a global emergency flag disables checks without requiring checked code to execute;
- original compiled methods/plans remain recoverable.

The original Gradualtalk work explicitly notes the practical need to disable runtime
cast insertion while working on critical system facilities.

### 20.6 Atomic installation

An instrumentation transaction MUST:

1. verify target method/version;
1. prepare all required artifacts;
1. install atomically where the platform permits;
1. register reverse mapping to original method/source;
1. publish active plan only after success;
1. roll back on partial failure.

### 20.7 Runtime violation object

`GradTContractViolation` SHOULD include:

```text
violation category
contract/obligation id
expected rendering
actual value and runtime class (safely summarized)
caller/callee/provider blame parties
boundary direction and trust regions
method/slot/block target
source location of declaration and generated check
analysis snapshot id and current/stale comparison
relevant old values
contract stack
ordinary execution stack
suggested debugger actions
```

Value rendering must avoid triggering arbitrary user code recursively; use guarded
inspectors/summaries.

### 20.8 Check failure policy

Policies MAY include:

- signal a resumable violation;
- signal a non-resumable error;
- log and continue;
- enter debugger;
- sample/report without enforcing.

The policy must be explicit and included in the plan. Resuming must not silently mark a
failed obligation as proved.

### 20.9 Runtime caching

Flat type contracts may cache class/subtype decisions keyed by class-hierarchy
generation. Structural checks may cache protocol conformance keyed by method-dictionary
generations. Cache entries MUST invalidate with live changes.

### 20.10 Performance safeguards

The runtime SHOULD:

- inline common nil/nominal checks;
- avoid repeated invariant checks inside one stable activation;
- avoid eager traversal of large collections unless requested;
- reuse immutable contract objects;
- record cost counters;
- support selective disablement by package, contract kind, or cost class;
- preserve a low-overhead path when enforcement is off.

______________________________________________________________________

## 21. Live-image consistency and invalidation

### 21.1 Principle

In a live Smalltalk image, analysis is valid only relative to a versioned world. A
method edit can invalidate callers; a class hierarchy change can invalidate subtype
decisions; an extension method can change a union/structural protocol; a slot
replacement can invalidate initialization analysis; and a provider edit can change
contracts without touching implementation code.

Gralk MUST therefore treat dependency tracking and invalidation as part of correctness,
not merely a performance cache.

The original Gradualtalk implementation identified this problem explicitly and
maintained dependencies, including dependencies on entities that did not yet exist. See
[Gradualtalk: A Gradually Typed Smalltalk](https://www.johanfabry.be/assets/allendeAl-scp2014.pdf)
and the [Gradualtalk project page](https://pleiad.cl/research/software/gradualtalk).

### 21.2 Dependency graph

`GradTDependencyGraph` contains versioned nodes and labeled edges.

Minimum node kinds:

```text
method body/version
method declaration/signature
class binding
class hierarchy edge
method dictionary/protocol
slot layout
slot semantic descriptor
class invariant
contract declaration
block/control summary
type alias
provider declaration
package/boundary policy
compiler semantics adapter version
analysis result
instrumentation plan
```

Example edge labels:

```text
resolves type name
calls/selects signature
uses subtype relation
uses method protocol
reads/writes slot
uses slot semantics
inherits contract
uses control lowering
uses effect summary
uses alias
protected by runtime plan
generated from analysis
```

### 21.3 Hard and soft dependencies

- A **hard dependency** invalidates the proof/result when changed.
- A **soft dependency** affects diagnostics, presentation, or optimization but not
  semantic validity.

For example, source formatting is usually soft; AST structure and method body are hard.
A contract profiler count is soft; active boundary policy is hard for an enforcement
plan.

### 21.4 Version stamps

Every resolvable entity SHOULD expose a monotonic generation or content fingerprint. A
generation is efficient inside one image session; a fingerprint is useful across
reloads.

Recommended stamps:

```text
binding generation
class definition/layout generation
superclass relation generation
method source/AST hash
compiled method identity/version
method dictionary generation
slot descriptor/version
registry declaration generation
package policy generation
```

Do not rely solely on timestamps.

### 21.5 Change event adapter

Gralk SHOULD subscribe to image changes through a small adapter over Pharo’s
announcement mechanisms rather than scatter exact system event classes throughout the
implementation.

```smalltalk
GradTChangeSource
  whenMethodChanged: aBlock
  whenClassChanged: aBlock
  whenHierarchyChanged: aBlock
  whenSlotsChanged: aBlock
  whenPackageChanged: aBlock
  whenDeclarationChanged: aBlock
  whenWorldReset: aBlock
```

The adapter maps version-specific announcements into Gralk events. The pragma system’s
`PragmaCollector`/system-announcement pattern is useful background:
[Pragmas: Literal Messages as Powerful Method Annotations](https://rmod-files.lille.inria.fr/Team/Texts/Papers/Duca16a-Official-Pragma-IWST.pdf).

### 21.6 Event-to-invalidation rules

#### Method body changed

Invalidate:

- that method’s CFG and analysis;
- inferred effect/block summaries;
- callers depending on inferred behavior;
- active instrumentation for the old method version;
- provider declarations if the method is a declaration carrier.

A pure declared signature need not invalidate all callers solely because implementation
changed, but contract/invariant verification and effect inference may.

#### Method added or removed

Invalidate:

- protocol/structural conformance for affected class and subclasses;
- sends previously resolving to another implementation or ghost;
- union common-protocol caches;
- override compatibility checks;
- ghost dependencies matching the key.

#### Class hierarchy changed

Invalidate:

- subtype/consistency caches;
- inherited methods/contracts/invariants;
- generic inheritance substitutions;
- override checks;
- all analysis using affected types.

#### Slot layout or slot class changed

Invalidate:

- slot resolution and semantics;
- definite-initialization results;
- invariant dependencies;
- read/write instrumentation;
- constructor analysis;
- object migration assumptions.

#### Type/contract declaration changed

Invalidate all targets and dependents using that declaration. If a sidecar declaration
becomes stale, deactivate its trusted proof and replace active runtime plans as
necessary.

#### Package/boundary policy changed

Static facts may remain valid, but enforcement plans and blame regions become stale.

### 21.7 Invalidation states

An analysis can transition:

```text
current -> invalidationPending -> stale -> reanalyzing -> current
                                     \-> incomplete/corrupt
```

The UI may temporarily show the last result, but it MUST label it stale and must not use
it to erase runtime checks or claim proof.

### 21.8 Reanalysis scheduler

`GradTReanalysisScheduler` SHOULD:

- debounce bursts of edits;
- batch related class/refactoring events;
- compute the transitive affected set;
- order by dependencies/strongly connected components;
- prioritize visible/open methods and runtime-protected boundaries;
- cancel superseded analysis jobs;
- verify generations before commit;
- expose progress without blocking ordinary editing.

A synchronous mode is needed for deterministic tests and CI.

### 21.9 Cycles

Recursive methods, mutually dependent signatures, and class cycles caused by corruption
may produce graph cycles.

- Legitimate method-analysis cycles should be processed as strongly connected components
  with iterative summaries.
- Illegal class hierarchy cycles should be reported as corrupt program model.
- Instrumentation MUST NOT be installed from a partially converged SCC unless explicitly
  allowed.

### 21.10 Refactoring transactions

Where the refactoring framework exposes transaction boundaries, Gralk SHOULD defer full
analysis until the transaction completes. During the transaction:

- affected results become `invalidationPending`;
- tools may display partial/ghost entities;
- runtime checks for old methods remain only if their targets still exist and are safe;
- no new proof is committed against an intermediate world.

If a refactoring aborts halfway, Gralk runs structural validation and reports
unresolved/corrupt dependencies rather than assuming rollback succeeded.

### 21.11 Class corruption and partial definitions

The resolver and registry MUST survive:

- missing superclass bindings;
- duplicate/ambiguous class names;
- missing slot classes;
- methods compiled against obsolete layouts;
- broken aliases;
- provider declarations targeting removed entities;
- an interrupted class rename.

A ghost/undefined-class representation is preferable to immediate failure. Background on
representing undefined classes as first-class objects:
[First-Class Undefined Classes for Pharo](https://hal.science/hal-01585305/document).

### 21.12 World validation and rebuild

Gralk MUST provide:

```smalltalk
GradTSystem current validateWorld.
GradTSystem current rebuildAllIndexes.
GradTSystem current discardAllCaches.
GradTSystem current disableAllInstrumentation.
GradTSystem current reconcileInstrumentation.
```

A full rebuild derives all semantic indexes from current pragmas and image structure.
Caches are disposable; declarations and source are authoritative.

### 21.13 Instrumentation invalidation

An active runtime plan is tied to exact target/declaration versions. On invalidation:

1. mark the plan stale immediately;
1. disable or revert it if continuing would enforce a false contract;
1. retain boundary safety with a conservative fallback where possible;
1. install the replacement only after new analysis succeeds;
1. report failures without leaving half-instrumented methods.

### 21.14 Proof leases

An optional useful abstraction is a **proof lease**: a runtime-erasure decision remains
valid only while a dependency token is current. The token references hierarchy, method,
slot, and declaration generations. This makes the relationship between live invalidation
and erased checks explicit.

______________________________________________________________________

## 22. Diagnostics and tooling

### 22.1 Structured diagnostics

Diagnostics MUST be objects, not preformatted strings.

Suggested fields:

```text
stable diagnostic id
category/code
severity
certainty
primary source location
related source/declaration locations
program/declaration keys
expected and actual semantic objects
flow path/branch explanation
unsafe/tainted assumptions
snapshot/status
suggested fixes
runtime obligation id, if any
suppression key
```

### 22.2 Severity and certainty

Keep severity separate from certainty.

Severity:

```text
info
hint
warning
error
fatal/toolFailure
```

Certainty:

```text
proved contradiction
conservative possibility
unsafe assumption
stale/incomplete
metadata conflict
runtime observation
```

A possible reflective invalidation may be severe but uncertain; a definite signature
mismatch is certain.

### 22.3 Core diagnostic categories

At minimum:

```text
unresolved type/class/method/slot
invalid send/protocol mismatch
argument mismatch
return mismatch
unsafe dynamic consistency/cast required
nullable receiver misuse
impossible/unreachable branch
local inference underconstrained
union widened
block may escape
unsafe non-local return
captured write not guaranteed
slot read before initialization
constructor fails to establish slots/invariant
object escapes during initialization
contract contradiction
unverified contract inheritance
stale sidecar declaration
conflicting declarations
reflection invalidates facts
analysis stale/incomplete/corrupt
instrumentation failure
```

### 22.4 Explain flow types

Tools SHOULD answer:

- What is the declared/base type here?
- What is the flow type at this AST node?
- Which condition refined it?
- Which assignment/effect invalidated a prior refinement?
- Why was a union widened?
- Which branch contributes each alternative?

This requires storing fact origins and join traces, at least in development builds.

### 22.5 Type-at-cursor and method view

The public tooling API SHOULD support:

```smalltalk
analysis typeAtSourcePosition: anInteger.
analysis flowStateAtSourcePosition: anInteger.
analysis obligationsAtSourcePosition: anInteger.
analysis dependenciesForNodeAt: anInteger.
analysis explainTypeAt: anInteger.
```

A method browser should show:

- declared signature and provider;
- observed/inferred local types;
- current/stale state;
- inserted/residual contracts;
- block control summaries;
- slot initialization facts;
- diagnostics grouped by source;
- navigation to sidecar declaration.

### 22.6 Contract debugger integration

On `GradTContractViolation`, the debugger SHOULD provide actions:

```text
browse contract declaration
browse generated obligation/static proof
inspect value safely
show caller/callee/provider blame
show typed/untyped boundary
show old values
show last slot writes (when tracing enabled)
show analysis snapshot and whether it is stale
rerun check
continue under a selected policy
suppress/disable this check for session
```

### 22.7 Live status dashboard

A Gralk system view SHOULD summarize:

- current/stale/incomplete methods;
- unresolved ghosts;
- declaration conflicts;
- unsafe reflective sites;
- active runtime checks and cost;
- stale instrumentation;
- reanalysis queue;
- packages by checking profile;
- top contract costs/violations.

### 22.8 Annotation suggestions

The checker MAY generate suggestions for:

- local declarations;
- method return/parameter types based on observations;
- block summaries inferred from simple implementations;
- constructors/initializers;
- missing slot policy;
- contracts that can now be promoted to types;
- declarations that have become stale.

Suggestions MUST remain reviewable edits, not silent metadata mutation.

### 22.9 Agent/tool query interface

Codex or other agents should use a stable query API rather than scraping UI strings.
Recommended services:

```smalltalk
GradTQueryService current
  analysisForMethodKey:;
  diagnosticsForPackage:;
  declarationAndOriginsForMethodKey:;
  explainSendAt:inMethod:;
  unresolvedDependencies;
  suggestedAnnotationsForMethod:;
  runtimePlansForPackage:.
```

Responses SHOULD be serializable to dictionaries/STON/JSON for external tooling, while
retaining native objects internally.

______________________________________________________________________

## 23. Caching, persistence, concurrency, and recovery

### 23.1 Authoritative data

Authoritative data consists of:

- current Smalltalk source/compiled structure;
- pragma metadata/provider methods;
- explicit project policy/configuration.

Analysis indexes, CFGs, solved types, and instrumentation plans are derived and
disposable.

### 23.2 Cache layers

Suggested cache layers:

```text
resolved declaration/type cache
subtype/protocol cache
AST/CFG cache
method analysis cache
constraint-solution cache
contract compilation cache
runtime class/protocol check cache
dependency reverse index
```

Every entry stores dependency generations. Cache APIs should return miss/stale
explicitly.

### 23.3 Persistent snapshots

Gralk MAY serialize derived indexes to accelerate image startup, but a snapshot must
include:

- Gralk schema/implementation version;
- Pharo/compiler adapter version;
- image/build fingerprint;
- package/declaration fingerprints;
- dependency generations/content hashes;
- checking profile.

On mismatch, discard the affected cache. Never deserialize live object identities as
durable proof.

STON is a plausible transport for optional caches or agent exchange, not an
authoritative annotation store: [STON repository](https://github.com/svenvc/ston).

### 23.4 Analysis concurrency

Even if most image mutation occurs on the UI process, background analysis must treat the
world as changing.

Rules:

1. Capture immutable/versioned inputs.
1. Do not mutate live compiler ASTs.
1. Avoid sending arbitrary application messages from background analysis.
1. Commit only after version validation.
1. Cancel results superseded by newer generations.
1. Serialize instrumentation installation with code changes.

### 23.5 Runtime concurrency

Per-process contract state is preferred for reentrancy/blame stacks. Shared caches
require synchronization or immutable copy-on-write structures.

Contracts on objects shared between processes cannot assume single-threaded stable-state
intervals. A concurrency-aware effect/profile may be added later; v0 should mark
cross-process publication and asynchronous blocks as unsafe boundaries.

### 23.6 Failure containment

Unexpected failures in analysis or instrumentation MUST be contained:

- analysis failure leaves ordinary compiled code usable;
- instrumentation failure rolls back;
- contract runtime failure can be globally bypassed;
- corrupted caches can be discarded;
- diagnostics distinguish application violations from Gralk defects.

### 23.7 Logging and audit

A bounded event log SHOULD capture:

```text
world changes relevant to Gralk
analysis start/commit/discard
invalidation causes
instrumentation install/remove
contract failures
emergency-disable actions
cache rebuilds
```

This is especially useful for diagnosing live-image race/invalidation bugs.

______________________________________________________________________

## 24. Security and trust considerations

### 24.1 Metadata is executable authority

A declaration can cause runtime wrappers, old-value reads, slot checks, or static check
erasure. Sidecar/provider metadata therefore has authority comparable to code.

Gralk SHOULD support package/provider trust levels and clearly display the source of
active contracts.

### 24.2 Contract expression safety

Default contract expressions MUST use the restricted validated language. Arbitrary
Smalltalk predicates are explicit unsafe contracts and may:

- mutate state;
- leak sensitive values;
- signal unexpectedly;
- diverge;
- recursively invoke checks.

Runtime modes may disable unsafe contracts in production.

### 24.3 Diagnostic privacy

Violation objects should not automatically print full object graphs or secrets. Value
rendering must be bounded and allow classes/slots to mark values sensitive.

### 24.4 Denial-of-service through contracts

Deep collection contracts and expensive invariants can dominate execution. Cost classes,
budgets, profiling, and selective activation are required. A provider must not be able
to label an arbitrary expensive predicate as constant-time without trust consequences.

### 24.5 Stale metadata as a trust failure

A fingerprint mismatch is not merely a warning when metadata is used to erase checks. In
verified-sidecar mode it invalidates the proof and either restores runtime checks or
marks the boundary unsafe.

______________________________________________________________________

## 25. Proposed packages and principal classes

The exact names may change, but responsibilities and dependency direction should remain.

### 25.1 `GradT-Core-Model`

```text
GradTEntityKey and subclasses
GradTSourceLocation
GradTVersionStamp
GradTResolutionResult
GradTDiagnostic
GradTPolicyProfile
GradTDependency
GradTStaticFact / GradTProposition
GradTAnalysisStatus
```

### 25.2 `GradT-Types-Core`

```text
GradTType hierarchy
GradTTypeRelation
GradTSubtypingEngine
GradTConsistencyEngine
GradTTypeNormalizer
GradTTypeSubstitution
GradTTypePrinter
```

### 25.3 `GradT-Metadata`

Implemented according to the companion metadata specification:

```text
pragma scanners/parsers
normalized declarations
registry snapshots
provider/conflict/fingerprint handling
```

Semantic clients access only normalized interfaces.

### 25.4 `GradT-ProgramModel`

```text
GradTProgramModel
GradTProgramSnapshot
GradTClassHandle
GradTMethodHandle
GradTSlotHandle
GradTGhostEntity
GradTCompilerAdapter
GradTMethodResolver
GradTProtocolResolver
```

### 25.5 `GradT-ControlFlow`

```text
GradTControlFlowBuilder
GradTControlFlowGraph
GradTBasicBlock
GradTCFGNode hierarchy
GradTControlLoweringRegistry
GradTSourceMap
```

### 25.6 `GradT-Flow`

```text
GradTFlowState
GradTLocation hierarchy
GradTLocationFact
GradTInitializationState
GradTFlowJoiner
GradTFactInvalidator
GradTPredicateInterpreter
GradTFixedPointEngine
```

### 25.7 `GradT-Inference`

```text
GradTConstraint hierarchy
GradTConstraintSet
GradTConstraintGenerator
GradTConstraintSolver
GradTPartialType hierarchy
GradTInferenceVariable
GradTInferenceTrace
```

### 25.8 `GradT-Analysis`

```text
GradTAnalysisService
GradTMethodAnalyzer
GradTExpressionTyper
GradTSendChecker
GradTReturnChecker
GradTOverrideChecker
GradTEffectAnalyzer
GradTMethodAnalysis
```

### 25.9 `GradT-Blocks`

```text
GradTBlockSummary
GradTBlockControlSummary
GradTBlockAnalyzer
GradTNonLocalReturnEffect
GradTCapturedCell
GradTBlockSummaryInference
```

### 25.10 `GradT-Slots`

```text
GradTSlotAdapter
GradTSlotDescriptor
GradTSlotSemanticsRegistry
GradTDefiniteInitializationAnalyzer
GradTConstructionState
GradTObjectEscapeAnalyzer
```

### 25.11 `GradT-Contracts-Core`

```text
GradTContract hierarchy
GradTContractExpression AST
GradTContractParser/Validator
GradTContractEvaluator
GradTContractStaticMeaning
GradTBlame
GradTContractViolation
GradTInvariantState
```

### 25.12 `GradT-TypeContracts`

```text
GradTTypeContractFactory
GradTContractResidualizer
GradTContractPromotion
GradTContractDepthPolicy
```

### 25.13 `GradT-Contracts-Runtime`

```text
GradTContractRuntime
GradTContractActivationPolicy
GradTContractStack
GradTInvariantTracker
GradTOldValueFrame
GradTContractProfiler
GradTEmergencyControl
```

### 25.14 `GradT-Contracts-Compiler`

```text
GradTEnforcementPlan
GradTEnforcementPlanner
GradTInstrumentationBackend
GradTReflectivityBackend
GradTCompilerBackend
GradTWrapperBackend (prototype)
GradTInstrumentationTransaction
```

### 25.15 `GradT-Live`

```text
GradTDependencyGraph
GradTChangeSource
GradTChangeEvent hierarchy
GradTInvalidationEngine
GradTReanalysisScheduler
GradTWorldValidator
GradTAnalysisCache
GradTInstrumentationReconciler
```

### 25.16 `GradT-Tools`

```text
GradTQueryService
GradTMethodTypeView
GradTSystemDashboard
GradTDiagnosticPresenter
GradTContractDebuggerExtension
GradTAnnotationSuggestion
GradTAgentExportService
```

### 25.17 Sidecar library packages

```text
GradT-Types-Kernel
GradT-Types-Collections
GradT-Types-Streams
GradT-Types-Exceptions
GradT-Types-Compiler (later/cautious)
GradT-Types-GToolkit (optional)
```

These packages contain declarations specified in the metadata companion document, tests,
and target-version compatibility information.

______________________________________________________________________

## 26. Public service APIs

The following sketches communicate responsibilities rather than final selector names.

### 26.1 Analysis service

```smalltalk
GradTAnalysisService >> analyzeMethod: aCompiledMethod
  | snapshot handle declarations cfg result |
  snapshot := programModel snapshotWithRegistry: registry snapshot.
  handle := snapshot resolveMethod: aCompiledMethod.
  declarations := registry declarationsFor: handle in: snapshot.
  cfg := controlFlowBuilder buildFor: handle declarations: declarations.
  result := methodAnalyzer
    analyze: handle
    cfg: cfg
    declarations: declarations
    snapshot: snapshot
    profile: policy current.
  (snapshot stillValidFor: result hardDependencies)
    ifTrue: [ self publish: result ]
    ifFalse: [ self discardAsStale: result ].
  ^ result
```

### 26.2 Type checking result

```text
GradTCheckResult
  status: proved | consistent | rejected | unresolved
  actualType
  expectedType
  residualContract
  diagnostics
  constraints
  effects
  abruptCompletions
```

### 26.3 Expression typing

```smalltalk
GradTExpressionTyper >> typeExpression: anASTNode expected: aTypeOrNil state: aFlowState
```

This MUST return a value object containing normal type/state and abrupt exits; it must
not mutate a shared global environment.

### 26.4 Program queries

```smalltalk
GradTProgramSnapshot >> signaturesForSend: selector receiverType: aType
GradTProgramSnapshot >> commonProtocolOfUnion: aUnionType
GradTProgramSnapshot >> slotDescriptorFor: aSlotKey
GradTProgramSnapshot >> effectSummaryFor: aMethodKey
GradTProgramSnapshot >> controlSummaryFor: aMethodKey
```

### 26.5 Flow operations

```smalltalk
GradTFlowState >> refine: aLocation to: aType because: anOrigin
GradTFlowState >> assign: aLocation type: aType because: anOrigin
GradTFlowState >> invalidate: aLocation because: anEffect
GradTFlowJoiner >> join: stateA with: stateB at: aJoinNode
```

### 26.6 Contracts

```smalltalk
GradTEnforcementPlanner >> planFor: aMethodAnalysis profile: aPolicy
GradTInstrumentationBackend >> installPlan: aPlan transactionallyIn: aSnapshot
GradTContractRuntime >> check: aContract subject: aValue blame: aBlameContext
```

### 26.7 Live invalidation

```smalltalk
GradTInvalidationEngine >> process: aGradTChangeEvent
  | changedNodes affected |
  changedNodes := dependencyGraph nodesChangedBy: aGradTChangeEvent.
  affected := dependencyGraph transitiveDependentsOfAll: changedNodes.
  analysisStore markStale: affected.
  instrumentationReconciler deactivateUnsafePlansFor: affected.
  scheduler enqueue: affected.
```

### 26.8 Agent export

```smalltalk
GradTAgentExportService >> reportForMethod: aMethodKey
```

should return a stable dictionary containing declarations, types, CFG summary,
diagnostics, dependencies, obligations, and source references without requiring UI
objects.

______________________________________________________________________

## 27. Core algorithms

### 27.1 Method analysis worklist

```text
analyzeMethod(method, snapshot):
  declarations := resolveDeclarations(method, snapshot)
  cfg := buildCFG(method.ast, declarations.controlSemantics)
  initialState := seedEnvironment(method, declarations)
  worklist := [cfg.entry]
  inState[cfg.entry] := initialState

  while worklist not empty:
    node := removeNext(worklist)
    result := transfer(node, inState[node])

    for each (edge, successor) in result.successors:
      edgeState := applyEdgeFacts(result.stateFor(edge), edge)
      joined := join(inState[successor], edgeState)
      widened := widenIfLoop(successor, joined)
      if widened differs from inState[successor]:
        inState[successor] := widened
        add successor to worklist

    collect result.abruptCompletions separately

  validate exits, inferred locals, slots, contracts, overrides
  solve remaining constraints/deferred nodes
  produce analysis and residual plan
```

### 27.2 Predicate refinement

```text
interpretCondition(expr, state):
  typed := type(expr, expected Boolean, state)
  declaration := refinementDeclarationFor(expr.resolvedSend)
  if declaration absent:
    return (typed.state, noFacts, noFacts)

  location := stableLocationNamedBy(declaration, expr)
  if location unavailable:
    return (typed.state, noFacts, noFacts + diagnostic)

  trueFacts := instantiate(declaration.trueFacts, location, typed)
  falseFacts := instantiate(declaration.falseFacts, location, typed)
  return (typed.state, trueFacts, falseFacts)
```

### 27.3 Union send checking

```text
checkSend(receiverUnion, selector, arguments):
  results := []
  for alternative in receiverUnion.alternatives:
    candidates := resolve(selector, alternative)
    if candidates empty:
      report selector missing for alternative
      return rejected
    results add checkCandidates(candidates, arguments)

  if any result rejected:
    return rejected
  normalType := union(results.normalTypes)
  effects := joinEffects(results.effects)
  residuals := combineResiduals(results)
  return proved/consistent(normalType, effects, residuals)
```

### 27.4 Local partial type

```text
assign(local, valueType):
  case local.inferenceState of
    unseen:
      if valueType is nil-only or empty generic:
        local := partial(valueType)
      else:
        local := inferred(valueType)

    partial:
      constraints := constrainPartial(local.partialType, valueType)
      if solved:
        local := inferred(solutionIncludingSentinelIfNeeded)

    inferred:
      local.baseType := widen(local.baseType, valueType)

    declared:
      check valueType against local.declaredType
```

### 27.5 Block invocation transfer

```text
applyBlockSummary(block, invocationSummary, incoming):
  blockOut := analyze block under captured state

  if invocation is exactlyOnce and synchronous and noescape:
    return blockOut.normalState

  if invocation is zeroOrOne:
    return join(incoming, blockOut.normalState)

  if invocation is zeroOrMore or oneOrMore:
    return loopFixedPoint(incoming, blockOut, minimumInvocation)

  if invocation mayEscape or timing unknown:
    return invalidateOrTaint(incoming, block.capturedWrites)
```

NLR effects are propagated to the home method only when the consumer permits them.

### 27.6 Definite slot initialization

```text
checkInitializer(method):
  state := constructionEntryState(method.receiverClass)
  result := analyzeCFG(method, state)

  for normalExit in result.normalExits:
    for slot in requiredOwnSlots(method.receiverClass):
      if normalExit.state[slot] != Initialized:
        report constructor/initializer obligation failure

    if objectInvariant not established:
      report invariant failure

  for escape in result.objectEscapes:
    if required state not established at escape:
      report premature escape
```

### 27.7 Contract residualization

```text
residualize(obligation, proofState):
  proof := staticProver.tryProve(obligation, proofState)
  case proof of
    proved:        no runtime contract
    partial:       simplify obligation using proof; emit residual
    contradicted:  diagnostic plus optional runtime trap
    unknown:       emit full contract
    tainted:       emit full contract with unsafe-origin blame
    impossible:    report unrepresentable runtime obligation
```

### 27.8 Invalidation commit check

```text
publish(result):
  if not result.snapshot.matchesCurrent(result.hardDependencies):
    mark result stale
    enqueue fresh analysis
    return false

  begin atomic store transaction
    replace current method analysis
    replace dependency edges
    reconcile runtime plan
  commit
  return true
```

______________________________________________________________________

## 28. Testing and verification strategy

### 28.1 Test layers

Gralk requires more than ordinary unit tests. Use these layers:

1. **Algebra/unit tests:** type normalization, relations, substitutions, joins,
   constraints.
1. **Parser/registry integration tests:** supplied by the companion metadata work.
1. **CFG golden tests:** AST input to normalized graph/edges/source mapping.
1. **Semantic golden tests:** source plus declarations to structured diagnostics and
   inferred facts.
1. **Runtime contract tests:** instrumentation, blame, violations, old values,
   invariants.
1. **Live mutation tests:** edit image entities and verify invalidation/reanalysis.
1. **Differential tests:** compare statically predicted obligations with runtime
   behavior on controlled examples.
1. **Property tests:** lattice laws, normalization idempotence, substitution invariants,
   cache invalidation.
1. **Performance tests:** analysis latency, incremental reanalysis, contract overhead,
   memory.
1. **Recovery tests:** deliberate analyzer/backend failures and partial class changes.

### 28.2 Type algebra properties

At minimum:

```text
normalize(normalize(T)) = normalize(T)
T | Never = T
T | T = T
Never <: T
substitution composition behaves consistently
join is commutative, associative (modulo widening), and idempotent
flow-state join is monotonic
widening eventually stabilizes
```

Where gradual consistency is intentionally non-transitive, tests must encode the
intended laws rather than assume subtyping properties.

### 28.3 Nil-flow corpus

Test:

- `isNil`/`notNil` true and false branches;
- early return leaves non-nil fallthrough;
- `ifNil:`/`ifNotNil:` block parameter/result semantics;
- union protocol intersection;
- custom `UndefinedObject` extension methods;
- invalidation after assignment or unknown mutation;
- `isKindOf:` refinement from `Object`;
- nested unions and widening.

### 28.4 Local inference corpus

Test:

- first assignment;
- `nil` partial type followed by non-nil assignment;
- empty generic collection followed by writes;
- incompatible assignments and configured widening;
- branch joins;
- loop joins;
- expected type flowing into a block/empty collection;
- underconstrained locals;
- explicit declarations overriding inference;
- inference error recovery.

### 28.5 Generic/collection corpus

Annotate a deliberately small but representative slice:

- `Collection`, `SequenceableCollection`, `Array`, `OrderedCollection`, `Set`,
  `Dictionary`;
- `add:`, `at:`, `at:put:`, `do:`, `collect:`, `select:`, `detect:ifNone:`;
- class-side constructors;
- streams/readers/writers in a later slice.

Tests must account for actual return-family behavior rather than impose an idealized
generic library.

### 28.6 Block/control corpus

Include:

- all Boolean conditional variants;
- short-circuit `and:`/`or:`;
- nil conditionals;
- `whileTrue:`/`whileFalse:`;
- `timesRepeat:` and iteration;
- `at:ifAbsent:` with NLR;
- exactly-once helper;
- zero-or-one helper;
- unknown/escaping callback;
- async/process callback;
- block returned/stored from home method;
- nested NLRs;
- `ensure:` and `ifCurtailed:` interaction;
- exceptions replacing or preserving abrupt completion.

### 28.7 Slot matrix

For each combination, test read, write, branch join, constructor, reflection, and
runtime guard:

```text
ordinary x nullable/required/lateinit
decorated x write-establishes or not
defaulted
computed
virtual
unknown/external
```

Use at least one real custom slot implementation in integration tests.

### 28.8 Contract tests

Test:

- precondition caller blame;
- postcondition callee blame;
- sidecar/provider stale blame;
- class invariant entry/exit and dirty state;
- old values captured once;
- inherited OR/AND composition;
- arbitrary predicate failure distinguished from subject failure;
- recursion guard;
- shallow/deep/use-site collection behavior;
- block argument/result wrappers;
- contract profiling;
- activation policies;
- emergency disable and rollback.

### 28.9 Live-image mutation scenarios

Automated integration tests should:

1. analyze a caller/callee pair;
1. edit callee signature/body/effect;
1. assert caller becomes stale;
1. assert old plan is disabled or conservatively replaced;
1. await/run synchronous reanalysis;
1. assert new result and dependencies.

Repeat for:

- class rename and failed halfway rename;
- superclass change;
- method addition/removal affecting structural conformance;
- slot replacement/layout change;
- provider pragma edit;
- missing class later loaded;
- package unload/reload;
- full cache discard/rebuild.

### 28.10 Golden diagnostic format

Golden tests SHOULD compare structured normalized output, not fragile presentation
strings. Normalize object identities, timestamps, and generated ids.

Example fixture:

```text
source
metadata declarations
profile
expected diagnostics (code, location, expected/actual types, certainty)
expected node types
expected residual obligations
expected dependencies
```

### 28.11 Differential static/runtime tests

For a controlled subset, generate values satisfying and violating types/contracts.
Verify:

- statically proved obligations do not fail at runtime under the same snapshot;
- retained residual checks fail with correct blame;
- mutations invalidate erased proof before unsafe execution;
- advisory taint results in runtime checking where configured.

This does not prove global soundness, but catches mismatches between static and runtime
semantics.

### 28.12 Performance baselines

Record at least:

```text
cold and warm method analysis time
incremental edit-to-current time
number of reanalyzed methods per edit
CFG/type/dependency memory per method
runtime overhead for nominal/nil boundary checks
invariant overhead
block wrapper overhead
collection contract overhead by policy
instrumentation install/remove time
```

Benchmarks should include tiny methods, typical application methods, and large
generated/compiler methods.

### 28.13 Acceptance test image

Maintain a small reproducible image/package set containing:

- typed and untyped packages;
- sidecar declarations for core classes;
- custom slots;
- reflection;
- callbacks and NLRs;
- deliberate stale/broken declarations;
- contracts and invariants;
- scripted live edits.

This becomes the primary end-to-end CI fixture for agents.

______________________________________________________________________

## 29. Agent-ready work breakdown

Each work package below should be independently assignable. Agents should commit tests
and documentation with implementation and should not redefine adjacent component
protocols without updating this specification or an accepted architecture decision
record.

### WP0 — Architecture decisions and executable vocabulary

**Goal:** Turn unresolved foundational names/policies into explicit decisions.

**Inputs:** This specification and the metadata companion.

**Deliverables:**

- architecture decision records for `Dynamic`/`Any`, union cap, checking profiles,
  public/stable boundary policy, initial Pharo version target;
- package skeletons and dependency tests;
- common result/status/diagnostic classes;
- a smoke test loading all empty packages without cycles.

**Acceptance criteria:**

- no circular package dependency;
- policy object can serialize/print active settings;
- downstream agents can import stable core abstractions.

**Dependencies:** none.

### WP1 — Type IR and relations

**Goal:** Implement immutable type objects, normalization, substitution, subtyping,
consistency, assignability, and rendering.

**Deliverables:**

- type hierarchy;
- nominal class handles decoupled from raw live objects;
- union normalization preserving nil alternatives;
- generic substitutions and `Self` variants;
- structured/nominal protocol interfaces;
- algebra/property tests.

**Acceptance criteria:**

- all laws in §28.2 pass;
- `Object`, `Dynamic`, `Never`, `UndefinedObject`, and unresolved/error types are
  distinct;
- assignment check returns proved/consistent/rejected/unresolved with explanation.

**Dependencies:** WP0.

### WP2 — Program model and registry snapshot integration

**Goal:** Resolve normalized metadata against a live but versioned image.

**Deliverables:**

- entity keys/handles;
- program snapshot;
- class/method/slot/protocol resolver;
- ghost entities;
- compiler/source adapter interface;
- structural validation against deliberately broken fixtures.

**Acceptance criteria:**

- missing entities return ghosts/results rather than exceptions;
- a snapshot detects method/class/slot replacement;
- name reuse does not silently preserve old class identity.

**Dependencies:** WP0, metadata implementation, optionally WP1.

### WP3 — CFG builder and control lowering

**Goal:** Lower method ASTs into source-mapped CFGs.

**Deliverables:**

- node/edge hierarchy;
- ordinary expression/send/assignment/return lowering;
- block subgraphs;
- explicit NLR nodes;
- Boolean/nil conditional lowering;
- loops;
- `ensure:`/`ifCurtailed:` skeleton semantics;
- golden graph printer/tests.

**Acceptance criteria:**

- abrupt exits do not join normal results;
- source mapping navigates back to AST/source;
- recognized control sends fall back safely when shape/declaration is invalid.

**Dependencies:** WP0, WP2.

### WP4 — Flow engine and occurrence typing

**Goal:** Implement locations, facts, branch propositions, join, invalidation, and fixed
points.

**Deliverables:**

- immutable/persistent or copy-safe flow state;
- predicate interpreter;
- stable-location rules;
- nil and `isKindOf:` refinements;
- loop worklist/fixed point;
- taint and fact-origin explanations.

**Acceptance criteria:**

- nil corpus passes;
- early abrupt branch refinement works;
- assignment and unknown effects invalidate expected facts;
- loops terminate under widening limit.

**Dependencies:** WP1–WP3.

### WP5 — Basic method checker and local inference

**Goal:** Check literals, reads/writes, sends, returns, and infer locals.

**Deliverables:**

- expression typer;
- send candidate checking;
- expected/contextual types;
- partial nil and empty-generic locals;
- branch/loop widening;
- observed method result;
- structured diagnostics.

**Acceptance criteria:**

- local inference corpus passes;
- compiler still produces methods with diagnostics;
- checker recovers from one error without cascades.

**Dependencies:** WP1–WP4.

### WP6 — Generic constraint solver and collection slice

**Goal:** Support method/class type variables and real basic collection protocols.

**Deliverables:**

- constraints, solver, inference trace;
- receiver substitution and expected result constraints;
- receiver-family result support;
- sidecar declarations/tests for a minimal collection slice;
- underconstrained-variable diagnostics.

**Acceptance criteria:**

- `OrderedCollection new` followed by writes infers element type;
- `collect:` infers block/result parameter;
- mutable invariance is enforced;
- actual Pharo collection return behavior is reflected in tests.

**Dependencies:** WP1, WP2, WP5, metadata sidecar work.

### WP7 — Block effects and non-local returns

**Goal:** Model block normal/abrupt effects, captures, invocation cardinality, escape,
and timing.

**Deliverables:**

- block summary;
- captured-cell model;
- control-summary instantiation;
- propagation rules for cardinalities;
- NLR home-method checking;
- unknown/escaping callback diagnostics;
- initial Kernel/Collections block-effect sidecars.

**Acceptance criteria:**

- exactly-once block writes propagate;
- zero-or-one and loops join correctly;
- `at:ifAbsent:` NLR is typed as home-method return, not block result;
- escaping/asynchronous NLR is rejected/warned per profile.

**Dependencies:** WP3–WP6.

### WP8 — Effects, slots, and construction analysis

**Goal:** Add effect summaries, slot adapters, definite initialization, and object
escape.

**Deliverables:**

- effect model and unknown-send policy;
- slot descriptor adapter;
- initialization lattice;
- ordinary/decorated/defaulted/computed/unknown handling;
- initializer/constructor analysis;
- precise and imprecise reflective slot access;
- `lateinit` residual obligation model.

**Acceptance criteria:**

- slot matrix passes;
- normal methods and initializer entry states differ correctly;
- required slot missing on one branch is diagnosed;
- unknown custom slot remains type-checkable without false DA proof;
- premature object escape is detected.

**Dependencies:** WP2, WP4, WP5, WP7.

### WP9 — Contract IR and evaluator

**Goal:** Build a standalone contract library before full runtime instrumentation.

**Deliverables:**

- contract hierarchy/AST;
- restricted expression validator/evaluator;
- pre/post/invariant/old semantics;
- static meaning interface;
- blame/violation objects;
- reentrancy guard;
- direct invocation test harness and profiler counters.

**Acceptance criteria:**

- caller/callee/provider failures are distinguished;
- old expressions evaluate once;
- invariant dirty/clean tracking works in harness;
- unsafe arbitrary predicates are explicit and not statically promoted.

**Dependencies:** WP0, WP2; can proceed in parallel with WP4–WP8.

### WP10 — Type/contract translation and enforcement planner

**Goal:** Generate residual contracts from types and erase/simplify proved obligations.

**Deliverables:**

- type-contract factory;
- shallow, transient/use-site, and initial lazy policies;
- residualizer;
- contract-to-fact promotion for nil/type/slot facts;
- backend-neutral enforcement plan;
- cost classification.

**Acceptance criteria:**

- nominal/union/block/simple generic obligations generate inspectable plans;
- proved obligations erase;
- partial proof simplifies contracts;
- mutable collection guarantees are not overstated.

**Dependencies:** WP1, WP5–WP9.

### WP11 — Instrumentation backend and runtime

**Goal:** Enforce method and invariant plans safely in a live image.

**Deliverables:**

- runtime activation policy;
- entry/exit/old/invariant execution;
- one transactional backend (prefer Reflectivity/compiler hook; wrapper allowed for
  prototype);
- reverse source/original mapping;
- rollback/emergency disable;
- structured debugger-visible violations.

**Acceptance criteria:**

- pre/post/invariant checks fire with correct blame/source;
- installation/removal is atomic under tests;
- critical Gralk packages can be excluded;
- failed installation leaves original method usable.

**Dependencies:** WP9, WP10, WP2/Pharo adapter.

### WP12 — Live dependency graph and incremental reanalysis

**Goal:** Make analyses and runtime plans correct under edits.

**Deliverables:**

- dependency graph/index;
- change adapter;
- invalidation rules;
- scheduler with synchronous test mode;
- snapshot commit validation;
- instrumentation reconciler;
- world validation/full rebuild.

**Acceptance criteria:**

- all live mutation scenarios in §28.9 pass;
- stale analysis is never presented as current proof;
- ghost dependencies resolve when code is loaded;
- a failed refactoring produces incomplete/corrupt status without crashing.

**Dependencies:** WP2, WP5, WP11; graph foundations may start earlier.

### WP13 — Tooling and agent interfaces

**Goal:** Make semantic information usable in the image and by Codex agents.

**Deliverables:**

- query service;
- type/flow explanation;
- method view;
- diagnostic presenter;
- system dashboard;
- contract debugger extension;
- serializable agent report.

**Acceptance criteria:**

- an agent can request one method report without UI scraping;
- every diagnostic navigates to source and declaration provider;
- stale/incomplete state is visible;
- contract failure links dynamic and static origins.

**Dependencies:** WP5 onward; can be delivered incrementally.

### WP14 — Core library annotation suites

**Goal:** Provide useful sidecar coverage without modifying upstream packages.

**Order:**

1. Kernel/Object/Boolean/UndefinedObject/BlockClosure control and refinements.
1. Collections and common enumerators.
1. Streams.
1. Exceptions/ensure/handlers.
1. Selected UI callbacks and process APIs.

**Deliverables:** declarations, fingerprints/version profiles, conformance tests,
behavioral tests.

**Acceptance criteria:** declarations resolve against the supported image; no silent
stale targets; behavior tests match actual implementation.

**Dependencies:** metadata registry and relevant semantic features.

### WP15 — Performance, profiling, and optimization

**Goal:** Establish costs before introducing hybrid strategies.

**Deliverables:**

- benchmark suite;
- analysis and contract profiler UI/export;
- hot-check inlining;
- cache tuning;
- optional hybrid placement experiments;
- performance regression thresholds.

**Acceptance criteria:** baseline numbers are reproducible; optimizations preserve
golden semantics; cost reports identify contracts by source/obligation.

**Dependencies:** functional end-to-end system.

______________________________________________________________________

## 30. Milestones

### M0 — Metadata and semantic substrate

- companion metadata registry functional;
- WP0–WP2 substantially complete;
- declarations resolve in a versioned snapshot;
- no actual method checking required.

### M1 — Nominal method checker

- type IR/relations;
- basic CFG;
- parameters, literals, sends, assignments, returns;
- structured diagnostics;
- no flow-sensitive refinements required yet.

### M2 — Flow-sensitive nil safety and locals

- branch/loop flow engine;
- `T | UndefinedObject` preservation;
- `isNil`, `notNil`, `isKindOf:` and nil controls;
- local partial types/inference;
- type-at-cursor.

### M3 — Blocks and Smalltalk control

- block signatures/summaries;
- captured variables;
- cardinality/escape/timing;
- NLR/`Never`;
- `ensure:`/`ifCurtailed:` baseline;
- core control sidecars.

### M4 — Generics and collections

- constraint solver;
- generic class/method substitution;
- core collection sidecar suite;
- receiver-family results;
- collection-oriented examples become useful.

### M5 — Slots and construction

- slot adapters;
- required/nullable/lateinit/defaulted/computed semantics;
- initializer/constructor checking;
- reflection/object escape;
- slot diagnostics/tooling.

### M6 — Contracts and boundary enforcement

- standalone contract IR/evaluator;
- type-contract translation;
- method/invariant runtime backend;
- blame/debugger integration;
- boundary profile.

### M7 — Live correctness

- complete dependency graph;
- invalidation/reanalysis;
- stale instrumentation reconciliation;
- ghost/corruption recovery;
- CI live-edit scenarios.

### M8 — Tooling and optimization

- dashboard and agent export;
- contract/analysis profiling;
- expanded library suites;
- performance tuning/hybrid experiments.

Milestones are cumulative. Runtime proof erasure SHOULD NOT be enabled broadly before
M7, because live invalidation is part of the validity of erased checks.

______________________________________________________________________

## 31. End-to-end semantic scenarios

These scenarios serve both as explanatory examples and acceptance tests.

### 31.1 Nil refinement with early return

```smalltalk
printSizeOf: value
  "value: String | UndefinedObject"
  value isNil ifTrue: [ ^ 0 ].
  ^ value size
```

Expected:

1. Entry type is union.
1. True branch refines to `UndefinedObject` and returns from method.
1. Normal fallthrough refines to `String`.
1. `size` is checked against `String` protocol.
1. Observed method result joins `SmallInteger` results, not `UndefinedObject`.

### 31.2 Common Object protocol on nullable union

```smalltalk
inspectKindOfString: value
  ^ value isKindOf: String
```

`value : T | UndefinedObject` can receive `isKindOf:` through common `Object` protocol.
The union remains intact for callers using the Boolean predicate as a refinement.

### 31.3 Partial nil local

```smalltalk
findName
  | result |
  result := nil.
  self objects do: [ :each |
    each isPreferred ifTrue: [ result := each name ] ].
  ^ result
```

Expected local type: `String | UndefinedObject` if `name` is `String`. Since `do:` may
execute zero times, nil remains.

### 31.4 Exactly-once captured write

```smalltalk
initializeName
  | name |
  name := nil.
  self evaluateOnce: [ name := 'default' ].
  ^ name size
```

With trusted exactly-once synchronous noescape summary, `name` is `String` after the
send. With no summary, it remains nullable/tainted and a diagnostic or residual check is
required.

### 31.5 Non-local return in `at:ifAbsent:`

```smalltalk
lookup: key
  ^ dictionary
    at: key
    ifAbsent: [ ^ self defaultValue ]
```

Expected:

- absent block normal result `Never`;
- NLR value checked against enclosing method return type;
- send’s normal result is dictionary value type, not unioned with default return;
- NLR accepted because summary is synchronous/noescape and permits it.

### 31.6 Escaping callback with NLR

```smalltalk
installCallback
  button whenPressedDo: [ ^ self close ]
```

Expected:

- callback summary says escaping/delayed/asynchronous or unknown;
- NLR is unsafe because home method will have returned;
- conservative profile emits error;
- advisory profile emits prominent warning/unsafe site and does not pretend runtime
  contract can make the dead home context valid.

### 31.7 Empty generic collection

```smalltalk
numbers
  | result |
  result := OrderedCollection new.
  result add: 1.
  result add: 2.
  ^ result
```

Expected: local generic variable solves to an integer element type; result
checked/suggested as `OrderedCollection<SmallInteger>` or configured widened numeric
type.

### 31.8 Branch-widened collection

```smalltalk
values: flag
  | result |
  result := OrderedCollection new.
  flag
    ifTrue: [ result add: 1 ]
    ifFalse: [ result add: 'one' ].
  ^ result
```

Expected element type: `SmallInteger | String` subject to union policy.

### 31.9 Required slot initialization

```smalltalk
initialize
  super initialize.
  enabled ifTrue: [ name := 'active' ]
```

If `name` is required, normal exit on false branch leaves it uninitialized. Report a
constructor/initializer diagnostic. A runtime invariant/guard may remain, but it does
not erase the static error.

### 31.10 `lateinit` read

```smalltalk
displayName
  ^ name asUppercase
```

If slot `name` is `lateinit String` and no receiver-state contract proves
initialization:

- static checker reports possible uninitialized read;
- boundary/debug profile emits a slot guard;
- failure signals a dedicated violation naming the slot and source.

### 31.11 Unknown custom slot

A virtual slot has declared read type `Point`, but no DA semantics. The read may be
type-checked as `Point`; Gralk must state that initialization proof is not applicable
and rely on the slot/contract runtime behavior.

### 31.12 Reflection invalidates slot facts

```smalltalk
name := 'known'.
self instVarNamed: dynamicName put: value.
^ name size
```

Conservative mode invalidates/taints all potentially targeted receiver slots. If
`dynamicName` is literal `#otherSlot`, `name` may remain known.

### 31.13 Manual contract promoted to static fact

```smalltalk
process: value
  "requires value notNil"
  ^ value size
```

A trusted recognized precondition refines the entry type. Runtime boundary mode still
checks it when callers are untyped. Fully typed proved callers may erase their redundant
check according to planner policy.

### 31.14 Class invariant stable boundary

```smalltalk
transferAllTo: another
  another deposit: balance.
  balance := 0
```

The invariant may be dirty between statements but must hold at public method exit.
Internal helper calls do not necessarily recheck it.

### 31.15 Sidecar becomes stale

1. A sidecar declares `Collection>>foo:`.
1. The target method is edited and its fingerprint changes.
1. Registry marks declaration stale.
1. Analyses using it become stale.
1. Any proof-erased checks depending on it lose their lease.
1. Runtime planner installs a conservative fallback or disables affected enforcement.
1. Tooling navigates to provider and changed target.

### 31.16 Missing class later loaded

1. A type refers to `FutureWidget`, currently absent.
1. Resolver creates a ghost and analysis is incomplete.
1. Package load defines the class.
1. change adapter resolves the ghost and schedules dependents.
1. new analysis becomes current without requiring manual cache reset.

### 31.17 Failed class rename

A rename changes some bindings/methods but fails before completion. Gralk must show
unresolved/ambiguous/corrupt entities, retain no current proof spanning the inconsistent
structure, and permit `validateWorld`/rebuild after repair.

### 31.18 Typed/untyped boundary failure

Untyped code passes a string into a typed method requiring `Integer`.

Violation should report:

```text
expected Integer
actual String/value summary
caller/value provider
callee/consumer
boundary packages
signature/provider declaration
generated check source
current snapshot/fingerprint
```

### 31.19 Live method edit during background analysis

1. Analyzer captures method version A.
1. User compiles version B before analysis completes.
1. Result for A fails snapshot commit check.
1. It is discarded/marked historical; never published as current.
1. Version B is queued.

______________________________________________________________________

## 32. Open decisions and recommended defaults

Every unresolved item should eventually become an architecture decision record. Until
then, use these defaults.

### 32.1 User-facing name for gradual unknown

**Decision needed:** `Any`, `Dynamic`, or another name.\
**Default:** internal `GradTDynamicType`; allow metadata spelling `#Any` only as an
alias with one documented meaning.

### 32.2 Nominal root and `ProtoObject`

**Decision needed:** whether the initial nominal universe includes direct `ProtoObject`
subclasses.\
**Default:** model the actual superclass graph; library sidecars may initially cover
only the `Object` branch. Do not encode “all values are Object” as a semantic axiom.

### 32.3 Union complexity

**Default:** preserve up to 8 alternatives; never collapse a simple nil union solely to
its nominal LUB; report widening.

### 32.4 Local widening policy

**Default:** union-widen inferred locals; declared locals keep fixed bound. Offer strict
single-type mode later.

### 32.5 Public/stable method boundary

**Default:** checked package external sends are public; same-package/helper sends are
internal unless metadata says otherwise. Protocol naming conventions may influence
tooling but should not be the sole soundness mechanism.

### 32.6 Unknown effects

**Default:** conservative profile invalidates receiver/argument facts according to alias
class; exploratory profile taints and generates residual checks.

### 32.7 Unknown block consumers

**Default:** may escape, may run zero or many times, timing/process unknown; NLR
rejected in conservative mode.

### 32.8 Constructor discovery

**Default:** explicit constructor/initializer metadata is authoritative. Recognize
conventional `initialize`/`new` only as suggestions until verified.

### 32.9 `lateinit`

**Default:** support non-null ordinary/decorated stored slots first, using physical nil
sentinel where valid. Defer nullable-lateinit.

### 32.10 Contract language

**Default:** restricted validated AST. Arbitrary Smalltalk blocks/predicates require
explicit unsafe form and have no static meaning.

### 32.11 Contract placement

**Default:** backend-neutral planner; begin with boundary/callee-style checks for
modularity and clear blame. Profile before hybrid duplication.

### 32.12 Mutable generic contracts

**Default:** do not claim lasting deep conformance from one eager traversal. Prefer
use-site/interposed checking or shallow documented guarantee.

### 32.13 Reflection

**Default:** precise when literal/resolvable; otherwise flag and invalidate/taint. Never
silently treat reflective code as pure.

### 32.14 Proof erasure

**Default:** limited until live dependency/instrumentation reconciliation is
operational. Static diagnostics can be useful much earlier.

### 32.15 Exception effects

**Default:** preserve abrupt CFG edges and `maySignal` effects, but defer checked
exception typing. Ensure/curtailment semantics are required earlier.

### 32.16 Cross-process blocks

**Default:** asynchronous/cross-process blocks cannot use NLR and cannot establish
immediate caller flow facts. Shared-state typing is advisory unless explicitly
synchronized/contracted.

### 32.17 Structural conformance depth

**Default:** selector/signature-level static conformance where declarations exist;
shallow selector-only checks labeled as such; behavioral contracts remain runtime
obligations.

### 32.18 Cache persistence

**Default:** in-memory disposable cache first. Add persistent cache only after
invalidation versions are reliable.

______________________________________________________________________

## 33. Definition of an end-to-end v0

The v0 system is complete when all of the following work together:

1. Pragma declarations from the companion spec load into a normalized, versioned
   registry.
1. A method resolves against a program snapshot, including ghosts for missing entities.
1. The CFG models ordinary branches, loops, method returns, block literals, and NLRs.
1. The checker supports nominal types, `Dynamic`, `Never`, unions, basic generics, and
   `Self`.
1. Nil unions refine through common predicates/control forms.
1. Locals support first-assignment inference and partial nil/empty collection types.
1. Common Kernel/Collection block consumers have control summaries.
1. NLRs are distinguished from block normal results and checked for escape safety.
1. Ordinary slots support nullable/required/lateinit and constructor analysis; unknown
   slots degrade honestly.
1. Flat pre/post/invariant contracts execute with blame and source mapping.
1. Nominal/union type obligations generate boundary contracts.
1. At least one transactional instrumentation backend is functional.
1. Method/class/slot/declaration edits invalidate results and plans.
1. Tools expose structured diagnostics, flow type at source, declaration origins, stale
   state, and contract violations.
1. Full cache/index rebuild and emergency instrumentation disable recover a broken
   session.

Deep generic wrappers, complete structural typing, inferred block summaries, and
advanced optimization are not required for v0.

______________________________________________________________________

## 34. Implementation guidelines for coding agents

1. **Do not interpret raw pragmas in semantic code.** Request normalized declarations
   from a registry snapshot.
1. **Do not use live object identity as durable semantic identity.** Use keys plus
   versioned handles.
1. **Do not return Boolean for rich checks.** Preserve
   proved/consistent/rejected/unresolved and explanations.
1. **Do not merge abrupt exits into normal result types.** Model them separately from
   the beginning.
1. **Do not collapse unions to nominal LUBs merely for convenience.** Apply explicit
   widening policy.
1. **Do not special-case nil outside the object model beyond declared refinement/control
   semantics.** `UndefinedObject` remains a real class.
1. **Do not assume blocks execute exactly once because they are literals.** Use control
   summaries.
1. **Do not assume slots are raw ivars.** Go through `GradTSlotAdapter`.
1. **Do not execute arbitrary slot or contract code during static analysis.** Consume
   semantic descriptors and restricted ASTs.
1. **Do not publish an analysis without revalidating its snapshot.**
1. **Do not erase runtime checks without dependency-tracked proof.**
1. **Do not hide uncertainty.** Emit structured stale/incomplete/unsafe states.
1. **Do not make type errors prevent ordinary interactive compilation by default.**
1. **Do not optimize before recording baseline semantics and costs.**
1. **Every new semantic feature must include:** declaration integration, dependency
   edges, diagnostics, query API, tests, and live invalidation behavior.

For each agent task, request:

```text
- affected packages/classes
- public protocols changed
- semantic rule implemented
- dependencies recorded
- diagnostics added
- tests and fixtures
- live invalidation impact
- runtime enforcement impact
- unresolved assumptions/ADRs needed
```

______________________________________________________________________

## 35. References and useful implementation sources

### 35.1 Gradualtalk / Gralk foundations

- [Gradualtalk project page](https://pleiad.cl/research/software/gradualtalk) —
  implementation overview, supported type forms, examples, and downloads.
- [Gradualtalk: A Gradually Typed Smalltalk](https://www.johanfabry.be/assets/allendeAl-scp2014.pdf)
  — architecture, type dictionary/checker, live dependencies, unions, generics, casts,
  and limitations including flow-sensitive typing/local inference.
- [Cast Insertion Strategies for Gradually-Typed Smalltalk](https://www.johanfabry.be/assets/allendeAl-dls2013.pdf)
  — caller, callee, and hybrid runtime-check placement tradeoffs.
- [Confined Gradual Typing](https://dcc.uchile.cl/TR/2014/TR_DCC-20140714-003.pdf) —
  restrictions and boundary design for typed/untyped interaction.

### 35.2 Smalltalk type-system precedent

- [Strongtalk: Typechecking Smalltalk in a Production Environment](https://bracha.org/oopsla93.pdf)
  — block types, generic protocols, nil unions, external protocol declarations, and the
  bottom-like type for non-yielding expressions.

### 35.3 Flow-sensitive and local inference implementation

- [Typed Racket occurrence typing guide](https://docs.racket-lang.org/ts-guide/occurrence-typing.html)
  — predicate-driven branch refinements.
- [Logical Types for Untyped Languages](https://arxiv.org/abs/1106.2575) — occurrence
  typing foundations.
- [`mypy/binder.py`](https://github.com/python/mypy/blob/master/mypy/binder.py) —
  flow-sensitive binding frames.
- [`mypy/checker.py`](https://github.com/python/mypy/blob/master/mypy/checker.py) —
  statement checking, partial types, deferred passes.
- [`mypy/checkexpr.py`](https://github.com/python/mypy/blob/master/mypy/checkexpr.py) —
  expression/call checking and binder refinements.
- [`mypy/infer.py`](https://github.com/python/mypy/blob/master/mypy/infer.py) — generic
  constraint inference.
- [MyPy type inference and annotations](https://mypy.readthedocs.io/en/stable/type_inference_and_annotations.html).

### 35.4 Contracts and runtime interposition

- [Eiffel: Design by Contract and Assertions](https://www.eiffel.org/doc/solutions/Design_by_Contract_and_Assertions)
  — preconditions, postconditions, invariants, and inheritance principles.
- [Racket contracts guide: function contracts](https://docs.racket-lang.org/guide/contract-func.html)
  — boundary checks and blame.
- [Racket contract reference](https://docs.racket-lang.org/reference/contracts.html) —
  flat/chaperone/impersonator contract hierarchy.
- [Building new Racket contract combinators](https://docs.racket-lang.org/reference/Building_New_Contract_Combinators.html).
- [Racket chaperones and impersonators](https://docs.racket-lang.org/reference/chaperones.html).
- [Chaperones and Impersonators: Run-time Support for Reasonable Interposition](https://www2.ccs.neu.edu/racket/pubs/oopsla12-sthff.pdf).
- [Racket contract profiler](https://docs.racket-lang.org/contract-profile/index.html).
- [Towards Practical Gradual Typing](https://www2.ccs.neu.edu/racket/pubs/ecoop2015-takikawa-et-al.pdf)
  — performance implications of gradual boundaries/contracts.

### 35.5 Pharo metadata, compiler, reflection, and live system

- [Pragmas: Literal Messages as Powerful Method Annotations](https://rmod-files.lille.inria.fr/Team/Texts/Papers/Duca16a-Official-Pragma-IWST.pdf)
  — pragma representation/querying and live pragma collection.
- [Opal: A New Compiler Architecture for Pharo](https://inria.hal.science/hal-00862411/document)
  — compiler architecture and control-flow compilation background.
- [Reflectivity: Sub-method, partial behavioral reflection for Pharo](https://inria.hal.science/hal-02480136v1/document)
  — AST-level MetaLink instrumentation.
- [Pharo repository](https://github.com/pharo-project/pharo) — current implementation
  source; exact APIs must be verified against the target image version.
- [Pharo features](https://pharo.org/features) — live object/class/method environment
  overview.
- [First-Class Undefined Classes for Pharo](https://hal.science/hal-01585305/document) —
  robust representation of missing class definitions.

### 35.6 Slots

- [Flexible Object Layouts: Enabling Lightweight Language Extensions by Intercepting Slot Access](https://doi.org/10.1145/2076021.2048138)
  — first-class slots and customized access semantics.
- [Typed slots for Pharo](https://medium.com/@juliendelplanque/typed-slots-for-pharo-98ba5d5aafbe)
  — practical typed-slot implementation example.

### 35.7 Blocks and non-local returns

- [About blocks, variables and blocks](https://thepharo.dev/2020/06/19/about-blocks-variables-and-blocks/)
  — captures and shared non-local variables.
- [Context and BlockClosure implementation](https://clementbera.wordpress.com/2015/01/21/context-and-blockclosure-implementation/)
  — contexts, closures, NLR implementation, and process restrictions.
- [Deep Into Pharo: Handling Non-Local Returns](https://eng.libretexts.org/Bookshelves/Computer_Science/Programming_Languages/Book%3A_Deep_into_Pharo_%28Bergel_Cassou_Ducasse_and_Laval%29/12%3A_Handling_Exceptions/12.03%3A_Handling_Non-Local_Returns)
  — `ensure:`, `ifCurtailed:`, and abnormal exits.

### 35.8 Optional serialization/tool interchange

- [STON](https://github.com/svenvc/ston) — possible format for disposable caches or
  agent reports; not a replacement for pragma-authoritative metadata.

______________________________________________________________________

## 36. Closing architectural rule

Gralk should be built around one invariant:

> Every static fact, erased check, runtime contract, diagnostic, and tool presentation
> must be traceable to a versioned program entity, a versioned declaration, and an
> explicit analysis assumption.

That traceability is what makes gradual typing, contracts, live editing, first-class
slots, reflection, and Smalltalk’s block control model coexist without pretending the
image is a closed immutable program.
