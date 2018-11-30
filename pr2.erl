% Brandon Blaschke Assignment 2
-module(pr2).
-import(re, [replace/3]).
-import(file, [read_file/1,close/1,open/2,write_file/2]).
-import(binary, [split/3]).
-import(io, [get_line/2, fwrite/2, format/3]).
-compile(export_all).

%
% A suite of functions for handling arithmetical expressions
%

% Expressions are represented like this
%
%     {num, N}
%     {var, A}
%     {add, E1, E2}
%     {mul, E1, E2}
%
% where N is a number, A is an atom,
% and E1, E2 are themselves expressions,

-type expr() :: {'num',integer()}
             |  {'var',atom()}
             |  {'add',expr(),expr()}
             |  {'mul',expr(),expr()}
             |  {'mod',expr(),expr()}
             |  {'idiv',expr(),expr()}.

% For example,
%   {add,{var,a},{mul,{num,2},{var,b}}
% represents the mathematical expression
%   (a+(2*b))

%
% Printing
%

% Turn an expression into a string, so that
%   {add,{var,a},{mul,{num,2},{var,b}}
% is turned into
%   "(a+(2*b))"

-spec print(expr()) -> string().

print({num,N}) ->
    integer_to_list(N);
print({var,A}) ->
    atom_to_list(A);
print({add,E1,E2}) ->
    "("++ print(E1) ++ "+" ++ print(E2) ++")";
print({mul,E1,E2}) ->
    "("++ print(E1) ++ "*" ++ print(E2) ++")";
print({mod, E1, E2}) ->
    "("++ print(E1) ++ "%" ++ print(E2) ++ ")";
print({idiv,E1, E2}) ->
    "("++ print(E1) ++ "#" ++ print(E2) ++ ")".

%
% parsing
%

% recognise expressions
% deterministic, recursive descent, parser.

% the function returns two things
%   - an expression recognised at the beginning of the string
%     (in fact, the longers such expression)
%   - whatever of the string is left
%
% for example, parse("(-55*eeee)+1111)") is             
%   {{mul,{num,-55},{var,eeee}} , "+1111)"}


% recognise a fully-bracketed expression, with no spaces etc.

% REMOVE FOR TESTING
removeStuff({H,T}) ->
    H.

% Reads a list of expressions from a text file and parses it. 
% Got the code for this here and made some changes https://stackoverflow.com/questions/2475270/how-to-read-the-contents-of-a-file-in-erlang
-spec readlines(string()) -> {string()}.

readlines(FileName) ->
    {ok, Device} = file:open(FileName, [read]),
    try get_all_lines(Device)
      after file:close(Device)
    end.

get_all_lines(Device) ->
    case io:get_line(Device, "") of
        eof  -> [];
        Line -> 
            NewLine = re:replace(Line, "$\n", "", [global,{return,list}]),
            [NewLine | get_all_lines(Device)]
    end.

parse(Line) -> 
    NewLine = re:replace(Line, "\s", "", [global,{return,list}]),
    parse2(NewLine).

-spec parse2(string()) -> {expr(), string()}.

parse2([$(|Rest]) ->                            % starts with a '('
      {E1,Rest1}     = parse2(Rest),            % then an expression
      [Op|Rest2]     = Rest1,                  % then an operator, '+' or '*'
      {E2,Rest3}     = parse2(Rest2),           % then another expression
      [$)|RestFinal] = Rest3,                  % starts with a ')'
      {case Op of
	  $+ -> {add,E1,E2};
	  $* -> {mul,E1,E2};
      $% -> {mod,E1,E2};
      $# -> {idiv,E1,E2}
        end,
       RestFinal};

% recognise an integer, a sequence of digits
% with an optional '-' sign at the start

parse2([Ch|Rest]) when ($0 =< Ch andalso Ch =< $9) orelse Ch==$- ->
    {Succeeds,Remainder} = get_while(fun is_digit/1,Rest),
    {{num, list_to_integer([Ch|Succeeds])}, Remainder};


% recognise a variable: an atom built of small letters only.

parse2([Ch|Rest])  when $a =< Ch andalso Ch =< $z ->
    {Succeeds,Remainder} = get_while(fun is_alpha/1,Rest),
    {{var, list_to_atom([Ch|Succeeds])}, Remainder}.

% Skips the white space characters in equation
% parse2([Ch|Rest])  when $\s =:= Ch ->
%     {parse2(Rest)}.

% auxiliary functions

% recognise a digit

-spec is_digit(integer()) -> boolean().

is_digit(Ch) ->
    $0 =< Ch andalso Ch =< $9.

% recognise a small letter

-spec is_alpha(integer()) -> boolean().

is_alpha(Ch) ->
    $a =< Ch andalso Ch =< $z.

% the longest initial segment of a list in which all
% elements have property P. Used in parsing integers
% and variables

-spec get_while(fun((T) -> boolean()),[T]) -> {[T],[T]}.    
%-spec get_while(fun((T) -> boolean()),[T]) -> [T].    
			 
get_while(P,[Ch|Rest]) ->
    case P(Ch) of
	true ->
	    {Succeeds,Remainder} = get_while(P,Rest),
	    {[Ch|Succeeds],Remainder};
	false ->
	    {[],[Ch|Rest]}
    end;
get_while(_P,[]) ->
    {[],[]}.

% Reads each line of text and parses that text, returning a list of paresed text
%-spec parseLines([string()]) -> [expr()].

parseLines([]) -> [];

parseLines([H | T]) ->
    Parsed = parse(H),
    Expr = removeStuff(Parsed),
    [Expr | parseLines(T)].

%
% Evaluate an expression
%

-type env() :: [{atom(),integer()}].

-spec eval(env(),expr()) -> integer().

eval(_Env,{num,N}) ->
    N;
eval(Env,{var,A}) ->
    lookup(A,Env);
eval(Env,{add,E1,E2}) ->
    eval(Env,E1) + eval(Env,E2);
eval(Env,{mul,E1,E2}) ->
    eval(Env,E1) * eval(Env,E2);
eval(Env, {mod, E1, E2}) ->
    eval(Env, E1) rem eval(Env,E2);
eval(Env, {idiv,E1,E2}) ->
    eval(Env, E1) div eval(Env,E2). 

% Evalulate multiple lines of a list of expressions, uses the default environment given
-spec evalLines([expr()]) -> [integer()].

evalLines([]) -> [];

evalLines([H | T]) ->
    Val = eval([{a,23},{b,-12}], H),
    [integer_to_list(Val) | evalLines(T)].


%
% Compiler and virtual machine
%
% Instructions
%    {push, N} - push integer N onto the stack
%    {fetch, A} - lookup value of variable a and push the result onto the stack
%    {add2} - pop the top two elements of the stack, add, and push the result
%    {mul2} - pop the top two elements of the stack, multiply, and push the result

-type instr() :: {'push',integer()}
              |  {'fetch',atom()}
              |  {'add2'}
              |  {'mul2'}
              |  {'mod2'}
              |  {'idiv2'}.

-type program() :: [instr()].

% compiler

-spec compile(expr()) -> program().

compile({num,N}) ->
    [{push, N}];
compile({var,A}) ->
    [{fetch, A}];
compile({add,E1,E2}) ->
    compile(E1) ++ compile(E2) ++ [{add2}];
compile({mul,E1,E2}) ->
    compile(E1) ++ compile(E2) ++ [{mul2}];
compile({mod,E1,E2}) ->
    compile(E1) ++ compile(E2) ++ [{mod2}];
compile({idiv,E1,E2}) ->
    compile(E1) ++ compile(E2) ++ [{idiv2}].

% run a code sequence in given environment and empty stack

-spec run(program(),env()) -> integer().
   
run(Code,Env) ->
    run(Code,Env,[]).

% execute an instruction, and when the code is exhausted,
% return the top of the stack as result.
% classic tail recursion

-type stack() :: [integer()].

-spec run(program(),env(),stack()) -> integer().

run([{push, N} | Continue], Env, Stack) ->
    run(Continue, Env, [N | Stack]);
run([{fetch, A} | Continue], Env, Stack) ->
    run(Continue, Env, [lookup(A,Env) | Stack]);
run([{add2} | Continue], Env, [N1,N2|Stack]) ->
    run(Continue, Env, [(N1+N2) | Stack]);
run([{mul2} | Continue], Env ,[N1,N2|Stack]) ->
    run(Continue, Env, [(N1*N2) | Stack]);
run([{mod2} | Continue], Env,[N1,N2|Stack]) ->
    run(Continue, Env, [(N1 rem N2) | Stack]);
run([{idiv2} | Continue], Env, [N1,N2|Stack]) ->
    run(Continue, Env, [(N1 div N2) | Stack]);
run([],_Env,[N]) ->
    N.

% compile and run ...
% should be identical to eval(Env,Expr)

-spec execute(env(),expr()) -> integer().
     
execute(Env,Expr) ->
    run(compile(Expr),Env).

% RUNNING THE PROGRAM

% Runs the program using eval method and writes output
mymain1() ->
    Lines = readlines("test.txt"),
    Parsed = parseLines(Lines),
    Values = evalLines(Parsed),
    Text = [string:join(Values, io_lib:nl()), io_lib:nl()],
    write_file("./output.txt", Text).


% Auxiliary function: lookup a
% key in a list of key-value pairs.
% Fails if the key not present.

-spec lookup(atom(),env()) -> integer().

lookup(A,[{A,V}|_]) ->
    V;
lookup(A,[_|Rest]) ->
    lookup(A,Rest).

% Test data.

% TEST 1 A: -1
-spec env1() -> env().    
env1() ->
    [{a,23},{b,-12}].

-spec expr1() -> expr().    
expr1() ->
    {add,{var,a},{mul,{num,2},{var,b}}}.

-spec test1() -> integer().    
test1() ->
    eval(env1(),expr1()).


% TEST 2 A: -12
-spec expr2() -> expr().    
expr2() ->
    {add,{mul,{num,1},{var,b}},{mul,{add,{mul,{num,2},{var,b}},{mul,{num,1},{var,b}}},{num,0}}}.

-spec test2() -> integer().
test2() ->
    eval(env1(),expr2()).

% TEST 3 25 % 5 A: 0
-spec expr3() -> expr().
expr3() ->
    {mod,{num, 25},{num,5}}.
-spec test3() -> integer().
test3() ->
    eval(env1(), expr3()).

% TEST 4 25 % 7 A: 4
-spec expr4() -> expr().
expr4() ->
    {mod,{num, 25},{num,7}}.
-spec test4() -> integer().
test4() ->
    eval(env1(), expr4()).

% TEST 5 3 % 100 A: 3
-spec expr5() -> expr().
expr5() ->
    {mod,{num, 3},{num,100}}.
-spec test5() -> integer().
test5() ->
    eval(env1(), expr5()).

% TEST 6 26 div 5 A: 5
-spec expr6() -> expr().
expr6() ->
    {idiv,{num, 26},{num,5}}.
-spec test6() -> integer().
test6() ->
    eval(env1(), expr6()).

% TEST 7 5 % 5 A: 5
-spec expr7() -> expr().
expr7() ->
    {idiv,{num, 5},{num,5}}.
-spec test7() -> integer().
test7() ->
    eval(env1(), expr7()).

% simplification ...

zeroA({add,E,{num,0}}) ->
    E;
zeroA({add,{num,0},E}) ->
    E;
zeroA(E) ->
    E.

mulO({mul,E,{num,1}}) ->
    E;
mulO({mul,{num,1},E}) ->
    E;
mulO(E) ->
    E.

mulZ({mul,_,{num,0}}) ->
    {num,0};
mulZ({mul,{num,0},_}) ->
    {num,0};
mulZ(E) ->
    E.

compose([]) ->
    fun (E) -> E end;
compose([Rule|Rules]) ->
    fun (E) -> (compose(Rules))(Rule(E)) end.

rules() ->
    [ fun zeroA/1, fun mulO/1, fun mulZ/1].

simp(F,{add,E1,E2}) ->
    F({add,simp(F,E1),simp(F,E2)});
simp(F,{mul,E1,E2}) ->
    F({mul,simp(F,E1),simp(F,E2)});
simp(_F,E) -> E.

simplify(E) ->
    simp(compose(rules()),E).
	     
