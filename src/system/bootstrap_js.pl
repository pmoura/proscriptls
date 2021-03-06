:- module(bootstrap_js,
        [append/3, assert/1, reverse/2, reverse/3, save_clausea/1, handle_term_expansion/1,
         include/1, (dynamic)/1, ensure_loaded/1, format/2,
         module/2, use_module/1,
         compile_message/1, (??) / 1, (?) / 1, otherwise/0, end_block/2, findall/3, setof/3, bagof/3,
         asserta/1, assertz/1, retract/1,
         unify_with_occurs_check/2, (\=) / 2, (\==) / 2, atomic/1, nonvar/1, number/1,
         open/3, close/1, flush_output/0, stream_property/2, at_end_of_stream/0, get_char/1, get_code/1, peek_char/1,
         put_char/1, peek_code/1, put_code/1, get_byte/1, peek_byte/1, put_byte/1, read_term/2, read/1, read/2,
         write_term/2, write/1, write/2, writeq/1, writeq/2, write_canonical/1, write_canonical/2,
         halt/0,
         callable/1, retractall/1, sort/2, keysort/2, length/2, delete/3,
         call_with_module/2,
         call/1, call/2, call/3, call/4, call/5, call/6, call/7, call/8,
         setup_call_cleanup/3,
         decode_instructions/2, yield/0
         ]).

:- use_module(not).

:- meta_predicate((
            call(0), call(1,?), call(2,?, ?), call(3, ?, ?, ?), call(4, ?, ?, ?, ?), call(5, ?, ?, ?, ?, ?), call(6, ?, ?, ?, ?, ?, ?), call(7, ?, ?, ?, ?, ?, ?, ?),
            retractall(:), asserta(:), assertz(:), retract(:),
            findall(?, ^, ?), setof(?, ^, ?), bagof(?, ^, ?),
            dynamic((:))
            )).

module(Name, Exports) :-
        wam_compiler:define_current_module(Name, Exports).

use_module(Spec) :-
        wam_compiler:define_use_module(Spec).

assert(Term):-
        assertz(Term).

save_clausea(_M1: M2: Term) :-
        !,
        save_clausea(M2 : Term).
save_clausea(M: (Head :- Body)) :-
        !,
        save_clausea((M: Head) :- (M:Body)).
save_clausea((_M1: M2: Head) :- Body) :-
        !,
        save_clausea((M2: Head) :- Body).
save_clausea(MH:Head:-(_MB1: MB2 :Body)):-
        !,
        save_clausea(MH:Head:-(MB2 :Body)).
save_clausea(ModuleName:Head:-(BodyModule:Body)):-
        !,
        wam_compiler:transform_meta_expression(Body, BodyModule, TransformedBody),
        save_clausea1(ModuleName:Head:-TransformedBody).
save_clausea(Term) :-
        save_clausea1(Term).

save_clausea1(ModuleName:Head:-Body):-
       !,
       Head =.. [Name|Args],
       length(Args, Arity),
       wam_compiler:transform_predicate_name(Name, Arity, ModuleName, TransformedName),
       TransformedHead =.. [TransformedName|Args],
       prepend_clause_to_predicate(TransformedName/Arity, TransformedHead, Body).
save_clausea1(Head:-Body):-
       !,
       Head =.. [Name|Args],
       length(Args, Arity),
       wam_compiler:current_compilation_module(ModuleName),
       wam_compiler:transform_predicate_name(Name, Arity, ModuleName, TransformedName),
       TransformedHead =.. [TransformedName|Args],
       prepend_clause_to_predicate(TransformedName/Arity, TransformedHead, Body).
save_clausea1(ModuleName:Fact):-
        !,
        Fact =.. [Name|Args],
        length(Args, Arity),
        wam_compiler:transform_predicate_name(Name, Arity, ModuleName, TransformedName),
        TransformedFact =.. [TransformedName|Args],
        prepend_clause_to_predicate(TransformedName/Arity, TransformedFact, true).
save_clausea1(Fact):-
        !,
        Fact =.. [Name|Args],
        length(Args, Arity),
        wam_compiler:current_compilation_module(ModuleName),
        wam_compiler:transform_predicate_name(Name, Arity, ModuleName, TransformedName),
        TransformedFact =.. [TransformedName|Args],
        prepend_clause_to_predicate(TransformedName/Arity, TransformedFact, true).

handle_term_expansion(_Head) :- true.

include(_).

call([H|T]) :-
        call('wam_compiler:consult'([H|T])).

call(Module : Goal):-
        !,
        call_with_module(Module, Goal).
call(Goal):-
        call_with_module(user, Goal).

call_with_module(_, Module : Goal) :-
        !,
        call_with_module(Module, Goal).
call_with_module(Module, Goal) :-
        %writeln(call(Module,Goal)),
        term_variables(Goal, Vars),
        % Compile this into a predicate, but do not actually declare it anywhere.
        % The functor is therefore irrelevant.
        % Call the anonymous predicate - $jmp does the trick here
        % Ensure that $jmp is not the last thing in a body, because foreign execute() will cause P <- CP after it succeeds
        % and it is safer to not mess with CP inside $jmp.
        (Module = user
          -> wam_compiler:compile_clause_2(query(Vars):-Goal),
            !,
            '$jmp'(Vars),
            true
        ;
         wam_compiler:push_current_compilation_module(Module, call),
         wam_compiler:compile_clause_2(query(Vars):-Goal),
         wam_compiler:pop_current_compilation_module(_, _),
         !,
         '$jmp'(Vars),
         true
        ).


dynamic(Module : Name/Arity) :-
        !,
        define_dynamic_predicate(Module : Name/Arity).
dynamic(_Module : []).
dynamic([]).
dynamic(Module : [H|T]) :-
        !,
        dynamic(Module : H),
        dynamic(Module : T).
dynamic(Module : (A,B)) :-
        dynamic(Module : A),
        dynamic(Module : B).

ensure_loaded(URL) :-
  wam_compiler:canonical_source(URL, CanonicalURL),
  (
  wam_compiler:'$loaded'(CanonicalURL)
    -> true
  ;
  'wam_compiler:consult'([CanonicalURL])
  ).

format(Format, Args):-
        current_output(Stream), format(Stream, Format, Args).

%compile_message(X):-writeln(X).
compile_message(_).

??(Goal):-
        setup_call_catcher_cleanup(format('CALL ~q~n', [Goal]),
                                   call(Goal),
                                   Catcher,
                                   ( Catcher == fail ->
                                       format('FAIL ~q~n', [Goal])
                                   ; Catcher == exit ->
                                       format('EXIT ~q~n', [Goal])
                                   ; Catcher == ! ->
                                       format('CUT  ~q~n', [Goal])
                                   ; Catcher = error(Error)->
                                       format('ERROR ~q ~p~n', [Goal, Error])
                                   )),
        ( var(Catcher)->
            format('PEND ~q~n', [Goal])
        ; otherwise->
            true
        ).

?(Goal):-
        functor(Goal, Functor, Arity),
        setup_call_catcher_cleanup(format('CALL ~q~n', [Functor/Arity]),
                                   call(Goal),
                                   Catcher,
                                   ( Catcher == fail ->
                                       format('FAIL ~q~n', [Goal])
                                   ; Catcher == exit ->
                                       format('EXIT ~q~n', [Functor/Arity])
                                   ; Catcher == ! ->
                                       format('CUT  ~q~n', [Functor/Arity])
                                   ; Catcher = error(Error)->
                                       format('ERROR ~q ~p~n', [Functor/Arity, Error])
                                   )),
        ( var(Catcher)->
            format('PEND ~q~n', [Functor/Arity])
        ; otherwise->
            true
        ).

otherwise.

% Exceptions are implement as per Bart Demoen's 1989 paper
% http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.57.4354&rep=rep1&type=pdf
/* This is now compiled directly to save on having call/1 in the code
catch(Goal, Catcher, Recovery):-
        get_current_block(Block),
        catch_1(Goal, Catcher, Recovery, Block).
catch_1(Goal, Catcher, Recovery, Block):-
        install_new_block(NewBlock),
        call(Goal),
        end_block(Block, NewBlock).
catch_1(Goal, Catcher, Recovery, Block):-
        reset_block(Block),
        get_exception(Ball),
        catch_2(Ball, Catcher, Recovery).

catch_2(Ball, Ball, Recovery):-
        clear_exception,
        !,
        call(Recovery).

catch_2(_, _, _):-
        unwind_stack.
*/

end_block(Block, NewBlock):-
        clean_up_block(NewBlock),
        reset_block(Block).

end_block(_, NewBlock):-
        reset_block(NewBlock),
        fail.


% setof/3, bagof/3, findall/3 and findall/4 as implemented by Richard O'Keefe and David Warren.
% http://www.j-paine.org/prolog/tools/files/setof.pl
% free_variables/4 is defined in not.pl, also from dec10 prolog tools.


findall(Template, Generator, List) :-
    findall(Template, Generator, [], List).

findall(Template, Generator, SoFar, List) :-
	save_instances(-Template, Generator),
	list_instances(SoFar, List).

set_of(Template, Filter, Set) :-
	bag_of(Template, Filter, Bag),
	sort(Bag, Set).

bag_of(Template, Generator, Bag) :-
	free_variables(Generator, Template, [], Vars),
	Vars \== [],
	!,
	Key =.. [.|Vars],
	functor(Key, ., N),
	save_instances(Key-Template, Generator),
	list_instances(Key, N, [], OmniumGatherum),
	keysort(OmniumGatherum, Gamut), !,
	concordant_subset(Gamut, Key, Answer),
	Bag = Answer.
bag_of(Template, Generator, Bag) :-
	save_instances(-Template, Generator),
	list_instances([], Bag),
	Bag \== [].

save_instances(Template, Generator) :-
	wam_util:existential_variables(Generator, _, Goal),
	recorda(., -, _),
	call(Goal),
	recorda(., Template, _),
	fail.
save_instances(_, _).

list_instances(SoFar, Total) :-
	recorded(., Term, Ref),
	erase(Ref), !,		%   must not backtrack
	list_instances(Term, SoFar, Total).

list_instances(-, SoFar, Total) :- !,
	Total = SoFar.		%   = delayed in case Total was bound
list_instances(-Template, SoFar, Total) :-
	list_instances([Template|SoFar], Total).

list_instances(Key, NVars, OldBag, NewBag) :-
	recorded(., Term, Ref),
	erase(Ref), !,		%  must not backtrack!
	list_instances(Term, Key, NVars, OldBag, NewBag).

list_instances(-, _, _, AnsBag, AnsBag) :- !.
list_instances(NewKey-Term, Key, NVars, OldBag, NewBag) :-
        replace_key_variables(NVars, Key, NewKey), !,
        list_instances(Key, NVars, [NewKey-Term|OldBag], NewBag).

replace_key_variables(0, _, _) :- !.
replace_key_variables(N, OldKey, NewKey) :-
	arg(N, NewKey, Arg),
	ground(Arg), !,
	M is N-1,
	replace_key_variables(M, OldKey, NewKey).
replace_key_variables(N, OldKey, NewKey) :-
	arg(N, OldKey, OldVar),
	arg(N, NewKey, OldVar),
	M is N-1,
	replace_key_variables(M, OldKey, NewKey).


concordant_subset([Key-Val|Rest], Clavis, Answer) :-
	concordant_subset(Rest, Key, List, More),
	concordant_subset(More, Key, [Val|List], Clavis, Answer).

concordant_subset([Key-Val|Rest], Clavis, [Val|List], More) :-
	Key == Clavis,
	!,
	concordant_subset(Rest, Clavis, List, More).
concordant_subset(More, _, [], More).

concordant_subset([],   Key, Subset, Key, Subset) :- !.
concordant_subset(_,    Key, Subset, Key, Subset).
concordant_subset(More, _,   _,   Clavis, Answer) :-
	concordant_subset(More, Clavis, Answer).


% ISO predicates
% 7.8.11 setup_call_cleanup/3
setup_call_cleanup(S, G, C) :-
    setup_call_catcher_cleanup(S, G, _, C).

% 8.2
% =/2 (foreign)
unify_with_occurs_check(A, A):- acyclic_term(A).
\=(A,B):- \+(A=B).

% 8.3 (Complete)
% var/1 (foreign)
% atom/1 (foreign)
% integer/1 (foreign)
% float/1 (foreign)
atomic(X):- (atom(X)-> true ; number(X)).
% compound/1 (foreign)
nonvar(X):- \+var(X).
number(X):- (integer(X)-> true; float(X)).

% 8.4
% @=</2 (foreign)
% ==/2 (foreign)
\==(A,B):- \+(A == B).
% @</2 (foreign)
% @>/2 (foreign)
% @>=/2 (foreign)

% 8.5
% functor/3 (foreign)
% arg/3 (foreign)
% =../2 (foreign)
% copy_term/2 (foreign)

% 8.6: Arithmetic.
% is/2 (foreign)

% 8.7: Arithmetic comparison
% =:=/2 (foreign)
% =\=/2 (foreign)
% (<)/2 (foreign)
% (=<)/2 (foreign)
% (>)/2 (foreign)
% (>=)/2 (foreign)

% 8.8 
% clause/2 (foreign)
% current_predicate/1 (foreign)

% 8.9

asserta(Term):- wam_compiler:compile_clause_2(Term), save_clausea(Term).
assertz(Term):- wam_compiler:compile_clause_2(Term), wam_compiler:save_clause(Term).

% separate the meta-predicate retract/1 predicate from the underlying
% implementation retract1/1. This prevents a cycle of the compiled
% code adding in a Module on the input term when trimming out modules (in retract1/1).

retract(Clause) :- retract1(Clause).

retract1(_M1 : _M2 : M3 : Term) :- !, retract1(M3 : Term).
retract1(_M1 : M2 : Term) :- !, retract1(M2 : Term).
retract1(_M1 : ((M2:Head) :- Body)) :- !, retract1((M2 : Head) :- Body).
retract1(M : (Head :- Body)) :- !, retract1((M : Head) :- Body).
retract1((_M1 : (M2 : Head)) :- Body) :- !, retract1((M2 : Head) :- Body).

retract1(Head:-Body):- !, retract_clause(Head, Body).
retract1(Fact):- !, retract_clause(Fact, true).

% abolish/1 (foreign)

% 8.10
% findall/3 (Implemented above)
setof(A,B,C):- set_of(A,B,C).
bagof(A,B,C):- bag_of(A,B,C).

% 8.11 streams
% current_input/1 (foreign)
% current_output/1 (foreign)
% set_input/1 (foreign)
% set_output/1 (foreign)
open(Resource, Mode, Stream):- open(Resource, Mode, Stream, []).
%open(_,_,_,_):- throw(no_files_in_javascript). % defined as foreign predicate for nodejs, undefined for browser.
% close/2 (foreign)
close(Stream):- close(Stream, []).
flush_output:- current_output(S), flush_output(S).
% flush_output/1 (foreign)
stream_property(Stream, Property):- var(Stream), !, current_stream(Stream), stream_property_1(Stream, Property).
stream_property(Stream, Property):- stream_property_1(Stream, Property).
at_end_of_stream:- current_output(S), at_end_of_stream(S).
% at_end_of_stream/1 (foreign)
% set_stream_position/2 (foreign)

% 8.12 char IO. 
% get_char/2 (foreign)
get_char(C):- current_input(S), get_char(S, C).
% get_code/2 (foreign)
get_code(C):- current_input(S), get_code(S, C).
% peek_char/2 (foreign)
peek_char(C):- current_input(S), peek_char(S, C).
% peek_code/2 (foreign)
peek_code(C):- current_input(S), peek_code(S, C).
% put_char/2 (foreign)
put_char(C):- current_output(S), put_char(S, C).
% put_code/2 (foreign)
put_code(C):- current_output(S), put_code(S, C).

% 8.13
% get_byte/2 (foreign)
get_byte(B):- current_input(S), get_byte(S, B).
% peek_byte/2 (foreign)
peek_byte(B):- current_input(S), peek_byte(S, B).
% put_byte/2 (foreign)
put_byte(B):- current_output(S), put_byte(S, B).

% 8.14 Term IO. 
% read_term/3 (foreign)
read_term(Term, Options):- current_input(S), read_term(S, Term, Options).
read(Term):-current_input(S), read_term(S, Term, []).
read(Stream, Term):- read_term(Stream, Term, []).
% write_term/3 (foreign)
write_term(Term, Options):- current_output(Stream), write_term(Stream, Term, Options).
write(Term):- current_output(S), write_term(S, Term, [quoted(false), ignore_ops(false), numbervars(true)]).
write(Stream, Term):- write_term(Stream, Term, [quoted(false), ignore_ops(false), numbervars(true)]).
writeq(Term):- current_output(Stream), write_term(Stream, Term, [quoted(true), ignore_ops(false), numbervars(true)]).
writeq(Stream, Term):- write_term(Stream, Term, [quoted(true), ignore_ops(false), numbervars(true)]).
write_canonical(Term):- current_output(Stream), write_term(Stream, Term, [quoted(true), ignore_ops(true), numbervars(false)]).
write_canonical(Stream, Term):- write_term(Stream, Term, [quoted(true), ignore_ops(true), numbervars(false)]).
% op/3 (foreign)
% current_op/3 (foreign)
% char_conversion/2 (foreign)
% current_char_conversion/2 (foreign)

% 8.15
% (\+)/1 (foreign)
% once/1 (foreign)
% repeat/0 (foreign)

% 8.16
% atom_length/2 (foreign)
% atom_concat/3 (foreign)
% sub_atom/5 (foreign)
% char_code/2 (foreign)
% atom_chars/2 (foreign)
% atom_codes/2 (foreign)
% number_codes/2 (foreign)
% number_chars/2 (foreign)

% 8.17
% set_prolog_flag/2 (foreign)
% current_prolog_flag/2 (foreign)
halt:- halt(0).
% halt/1 (foreign).

% Corrigendum
% compare/3 (foreign)
% sort/2 (above)
% keysort/2 (above)
% ground/1 (foreign)
% call/2-8 Implemented in this file
% false/0 (foreign)
callable(X):- (atom(X) -> true ; compound(X)).
% subsumes_term/2 (foreign)
% acyclic_term/1 (foreign)
% term_variables/2 (foreign)

retractall(Clause) :- retractall1(Clause).

retractall1(_M1 : (_M2 : (M3 : Goal))):- !, retractall1(M3 : Goal), fail.
retractall1(_M1 : (M2 : Goal)):- !, retractall1(M2 : Goal), fail.
retractall1(Goal):- retract1(Goal), fail. % Use the non-meta-predicate version of retract/1. retractall/1 already added Module info if appropriate.
retractall1(_).

sort(List, Sorted) :-
    check_sorted(List, Sorted),
    !.
sort(List, Sorted) :-
    sort1(List, Sorted, []).

sort1([X|Xs], Ys, YsTail) :-
    !,
    sort2(X, Xs, Ys, YsTail).
sort1([], Ys, Ys).

sort2(X, Xs, Ys, YsTail) :-
    partition(Xs,X,Left,Right),
    sort1(Left,Ys, [X|Rs]),
    sort1(Right,Rs, YsTail).

% check_sorted removes duplicates in an
% already-in-order list.

check_sorted([], []).
check_sorted([H], [H]) :- !.
check_sorted([H1,H2|T], L) :-
    (H1 @< H2
      -> L = [H1|LT]
    ;
    H1 == H2
      -> L = LT
    ),
    check_sorted([H2|T], LT).

keysort(List, Sorted) :-
    check_keysorted(List, Sorted),
    !.
keysort(List, Sorted) :-
    keysort1(List, Sorted, []).

check_keysorted([], []).
check_keysorted([X], [X]) :- !.
check_keysorted([H1-V1,H2-V2|T], L) :-
    (H1 @< H2
      -> L = [H1-V1|LT],
         Next = [H2-V2|T]
    ;
    H1 == H2
      -> L = LT,
         Next = [H1-V1|T]
    ),
    check_keysorted(Next, LT).

keysort1([Key-X|Xs],Ys, YsTail) :-
	key_partition(Xs, Key, Left, EQ, EQT, Right),
	keysort1(Left,  Ys, [Key-X|EQ]),
	keysort1(Right, EQT, YsTail).
keysort1([],Ys,Ys).

partition([X|Xs],Y,Ls,Rs) :-
        X == Y,
        !,
        partition(Xs, Y, Ls, Rs).
partition([X|Xs],Y,[X|Ls],Rs) :-
        X @< Y,
        !,
        partition(Xs,Y,Ls,Rs).
partition([X|Xs],Y,Ls,[X|Rs]) :-
%        X @> Y,
        !,
        partition(Xs,Y,Ls,Rs).
partition([],_,[],[]).

key_partition('-', _, _, _, _, _) :-
	throw(instantiation_error).
key_partition([XKey-X| Xs], YKey, [XKey-X| Ls], EQ, EQT, Rs) :-
	XKey @< YKey,
	!,
	key_partition(Xs, YKey, Ls, EQ, EQT, Rs).
key_partition([XKey-X| Xs], YKey, Ls, [XKey-X| EQ], EQT, Rs) :-
	XKey == YKey,
	!,
	key_partition(Xs, YKey, Ls, EQ, EQT, Rs).
key_partition([XKey-X| Xs], YKey, Ls, EQ, EQT, [XKey-X| Rs]) :-
%	XKey @> YKey,
	!,
	key_partition(Xs, YKey, Ls, EQ, EQT, Rs).
key_partition([], _, [], EQT, EQT, []).


append([],Ys,Ys).
append([X|Xs],Ys,[X|Zs]) :-
        append(Xs,Ys,Zs).

reverse(List, Reversed) :-
	reverse(List, [], Reversed).

reverse([], Reversed, Reversed).
reverse([Head|Tail], Sofar, Reversed) :-
	reverse(Tail, [Head|Sofar], Reversed).


length(L, N) :-
        length(L, 0, N).

length([], K, K) :- !.
length([_|T], J, K) :-
        N is J + 1,
        length(T, N, K).

%   delete(List, Elem, Residue)
%   is true when List is a list, in which Elem may or may not occur, and
%   Residue is a copy of List with all elements equal to Elem deleted.

delete([], _, []) :- !.
delete([Kill|Tail], Kill, Rest) :- !,
	delete(Tail, Kill, Rest).
delete([Head|Tail], Kill, [Head|Rest]) :- !,
	delete(Tail, Kill, Rest).


add_args(Structure, ExtensionArgs, ExtendedStructure) :-
        Structure =.. [Functor|OriginalArgs],
        append(OriginalArgs, ExtensionArgs, NewArgs),
        ExtendedStructure =.. [Functor|NewArgs].

call(A, B) :-
        call_extension(A, [B]).

call(A, B, C) :-
        call_extension(A, [B,C]).

call(A, B, C, D) :-
        call_extension(A, [B,C,D]).

call(A, B, C, D, E) :-
        call_extension(A, [B,C,D,E]).

call(A, B, C, D, E, F) :-
        call_extension(A, [B,C,D,E,F]).

call(A, B, C, D, E, F, G) :-
        call_extension(A, [B,C,D,E,F,G]).

call(A, B, C, D, E, F, G, H) :-
        call_extension(A, [B,C,D,E,F,G,H]).

call_extension('user::'(M, A), ExtensionArgs) :-
        !,
        call_extension_with_module(M, A, ExtensionArgs).
call_extension(M : A, ExtensionArgs) :-
        !,
        call_extension_with_module(M, A, ExtensionArgs).
call_extension(A, ExtensionArgs) :-
        call_extension_with_module(user, A, ExtensionArgs).

call_extension_with_module(_, 'user::'(M, A), ExtensionArgs):-
        !,
        call_extension_with_module(M, A, ExtensionArgs).
call_extension_with_module(_, M : A, ExtensionArgs):-
        !,
        call_extension_with_module(M, A, ExtensionArgs).
call_extension_with_module(M, A, ExtensionArgs):-
        add_args(A, ExtensionArgs, AA),
        call_with_module(M, AA).

decode_instructions(PredicateName, Codes) :-
    length(Codes, Length),
    decode_instructions(PredicateName, Codes, 0, Length).

decode_instructions(_PredicateName, _Codes, BeyondEnd, BeyondEnd) :- !.
decode_instructions(PredicateName, Codes, Current, BeyondEnd) :-
    Current < BeyondEnd, % sanity check
    decode_instruction(PredicateName, Codes, Current, instruction(StringCodes, Op, OpName, Size, GoalPredicate)),
    atom_codes(Atom, StringCodes),
    writeln(inst(Atom, Op, OpName, Size, GoalPredicate)),
    Next is Current + Size,
    decode_instructions(PredicateName, Codes, Next, BeyondEnd).

% yield/0 yields the single Javascript thread from the control of the WAM to
% any Javascript events that are queued waiting to evaluate then resumes execution
% of the WAM. Common events are page rendering actions such as drawing to a canvas
% or writing to an HTMLElement (e.g. the ProscriptLS Interpreter may have output
% waiting to be displayed).
%
% yield/0 sets up a delayed promise_backtrack() callback then halts the WAM.
% After halting the WAM (but leaving all of its global data intact) Javascript control
% eventually returns to the top level allowing events to be raised and handled.
% Finally the delayed promise_backtrack() callback is encountered and evaluated.
% this backtracks the WAM global state so that the second yield/0 clause is active
% then calls the WAM. On entry to the WAM the second yield/0 clause is evaluated and
% succeeds and the evaluation of the program that called yield/0 continues.

yield :-
    eval_javascript('state.wamYielded = true; setTimeout(() => {state.wamYielded = false;promise_backtrack();}, 0)'),
    halt.
yield :-
    true.
