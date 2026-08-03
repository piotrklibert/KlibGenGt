"
Construct bounded AST rewrite refactorings and expose their executable-block status.

- Slots
  - none
- Public API
  - {{gtMethod:KGASTRewriteRefactoringAdapter>>#buildIn:request:}}
    Construct a `KGASTRewriteRefactoring` after validating pattern-block opt-in.
"
Class {
	#name : 'KGASTRewriteRefactoringAdapter',
	#superclass : 'KGRefactoringAdapter',
	#category : 'KlibGenGt-Tools',
	#package : 'KlibGenGt-Tools'
}

{ #category : 'building' }
KGASTRewriteRefactoringAdapter >> buildIn: aModel request: aRequest [
	<arg: #aModel type: #GtRBNamespace>
	<arg: #aRequest type: #(Dictionary<String, Any>)>
	<return: #KGASTRewriteRefactoring>
	| refactoring |
	refactoring := KGASTRewriteRefactoring model: aModel request: aRequest.
	(refactoring containsPatternBlocks and: [ (aRequest at: 'allowPatternBlocks' ifAbsent: [ false ]) ~= true ]) ifTrue: [
		self error: 'AST pattern blocks require allowPatternBlocks=true' ].
	^ refactoring
]

{ #category : 'catalog' }
KGASTRewriteRefactoringAdapter >> frameworkClassName [ <return: #String> ^ 'RBParseTreeRewriter'
]

{ #category : 'catalog' }
KGASTRewriteRefactoringAdapter >> identifier [ <return: #String> ^ 'rewrite.ast'
]

{ #category : 'catalog' }
KGASTRewriteRefactoringAdapter >> requiredArguments [ <return: #(Array<String>)> ^ #('patternKind' 'search' 'replace')
]

{ #category : 'catalog' }
KGASTRewriteRefactoringAdapter >> requiresScope [ <return: #Boolean> ^ true
]

{ #category : 'catalog' }
KGASTRewriteRefactoringAdapter >> safetyNotes [ <return: #(Array<String>)> ^ #('project-packages-only' 'preview-before-apply' 'bounded-scope' 'pattern-blocks-require-opt-in')
]

{ #category : 'catalog' }
KGASTRewriteRefactoringAdapter >> targetKind [ <return: #String> ^ 'scope'
]
