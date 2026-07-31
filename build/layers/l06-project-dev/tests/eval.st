| expression result |
expression := Smalltalk os environment at: 'GT_EVAL'.
result := Smalltalk compiler evaluate: expression.
Stdio stdout nextPutAll: result printString; lf; flush.
Smalltalk exit: 0
