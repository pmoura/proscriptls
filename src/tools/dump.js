let environment =  'console'; // 'browser';

function dump(filter) {
    if(environment === 'console') {
        load_state();
    }
    for(var ofst = 0;ofst < ftable.length;ofst++) {
        var functionPair = ftable[ofst];
        var predicateName = atable[functionPair[0]];
        let predicate = predicates[ofst];
        if (!filter || (filter && ((filter === 'defined-predicate' && predicate)
            || (filter === 'undefined-predicate' && !predicate)))) {
            dumpWrite(predicateName + '/' + functionPair[1] + ': ftor=' + ofst + ', atable ofst=' + functionPair[0] + ', ' + (predicate ? 'has' : 'no') + ' predicate clauses');
        }
    }
}

function dumpPredicate(targetPredicateName, targetArity) {
    if(environment === 'console') {
        load_state();
    }

    for(var ofst = 0;ofst < ftable.length;ofst++){
        var functionPair = ftable[ofst];
        var predicateName = atable[functionPair[0]];
        if(predicateName === targetPredicateName && (! targetArity || functionPair[1] === targetArity)) {
            dumpWrite(predicateName + '/' + functionPair[1]);
            for(let clauseKey of predicates[ofst].clause_keys) {
                dumpWrite('---');
                dumpWrite('Clause ' + clauseKey);
                dumpWrite(' ');
                let clause = predicates[ofst].clauses[clauseKey];
                code = clause.code;
                let position = 0;
                while(position < code.length) {
                    let decoded = decode_instruction({key:ofst},position);
                    dumpWrite(decoded.string);
                    position += decoded.size;
                }
            }
            return;
        }
    }
}

function dumpWrite(msg) {
    if(environment === 'console') {
        print(msg);
    } else if(environment === 'browser') {
        console.log(msg);
    }
}