% hook file for ProscriptLS

%% Count is passed on the command line as the 1st argument
%
%get_count(Count) :-
%	argument_value(1, ACount),
%	number_atom(Count, ACount).

get_cpu_time(D) :-
    wam_duration(D).

nl :-
    writeln('').
