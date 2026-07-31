| results invalid |
results := KGCheckTypePragmas new inProject.
invalid := results reject: [ :each | each at: #valid ].
invalid ifNotEmpty: [
    invalid do: [ :each |
        Stdio stderr
            nextPutAll: (each at: #class) asString; nextPutAll: ' | ';
            nextPutAll: (each at: #source); nextPutAll: ' | ';
            nextPutAll: (each at: #type); nextPutAll: ' | ';
            nextPutAll: (each at: #message); lf ].
    Stdio stderr flush.
    Smalltalk exit: 1 ].
Stdio stdout nextPutAll: 'Checked '; nextPutAll: results size printString;
    nextPutAll: ' documentation type annotations.'; lf; flush.
Smalltalk exit: 0
