:- module(url, [current_compile_url/1, push_current_compile_url/1, pop_current_compile_url/1, convert_URL_to_base/2, url_directory/2, resolve_url/3]).

:- if((current_predicate(wam_compiler:current_compile_url/1), current_compile_url(_))).
    :- use_module(bootstrap_js). % for append/3
:- endif.

:-dynamic('$current_compile_url'/1).

current_compile_url(URL) :-
  '$current_compile_url'([URL|_]).

push_current_compile_url(URL) :-
  (retract('$current_compile_url'(URLs))
    -> true
   ;
   URLs = []
  ),
  asserta('$current_compile_url'([URL|URLs])).

pop_current_compile_url(URL) :-
  retract('$current_compile_url'([URL|URLs])),
  asserta('$current_compile_url'(URLs)).

convert_URL_to_base(URL, BaseURL) :-
  absolute_url(URL)
    -> URL = BaseURL
  ;
  current_compile_url(ReferenceURL)
    -> url_directory(ReferenceURL, ReferenceDirectory),
       resolve_url(ReferenceDirectory, URL, BaseURL)
  ;
  absolute_file_name(URL, Absolute, [])
    -> BaseURL = Absolute.

absolute_url(URL) :-
  atom_codes(URL, URLCodes),
  (append(":", _, Suffix),
   append(_, Suffix, URLCodes)
    -> true
  ;
  append("/", _, URLCodes)
  ).

url_directory(URL, Directory) :-
  atom_codes(URL, URLCodes),
  append("/", _, TestSuffix),
  append("/", FileCodes, Suffix),
  (append(Prefix, Suffix, URLCodes),
  \+ append(_, TestSuffix, FileCodes)
    -> append(Prefix, "/", DirectoryCodes),
       atom_codes(Directory, DirectoryCodes)
  ;
  Directory = './'
  ).


resolve_url('./', URL, URL) :- !.


resolve_url(Directory, URL, BaseURL) :-
  atom_codes(URL, URLCodes),
  sub(Directory, URLCodes, BaseURL).

sub(Directory, URLCodes, BaseURL) :-
  append("../", PrefixCodes, URLCodes)
    -> trim_directory(Directory, TrimmedDirectory),
       atom_codes(Prefix, PrefixCodes),
       resolve_url(TrimmedDirectory, Prefix, BaseURL)
   ;
   atom_codes(Directory, DirectoryCodes),
   append(DirectoryCodes, URLCodes, BaseURLCodes),
   atom_codes(BaseURL, BaseURLCodes).


% TrimmedDirectory is Directory with the last component
% removed. Directory = 'X/Y/' -> TrimmedDirectory = 'X/'.

trim_directory(Directory, TrimmedDirectory) :-
  atom_codes(Directory, DirectoryCodes),
  reverse(DirectoryCodes, ReversedCodes), % '/_RY/RX'
  append("/", RA, ReversedCodes), % RA = '_RY/RX'
  append(_RY, "/", RB),              % RB = _RY/
  append(RB, RX, RA),
  append("/", RX, RC),              % RC = /RX
  reverse(RC, C),
  atom_codes(TrimmedDirectory, C).
