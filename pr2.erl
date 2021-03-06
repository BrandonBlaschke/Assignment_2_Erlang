% Brandon Blaschke Assignment 2
-module(pr2).
-import(re, [replace/3]).
-import(file, [read_file/1,close/1,open/2,write_file/2]).
-import(binary, [split/3]).
-import(io, [get_line/2, fwrite/2, format/3, format/2]).
-import(lists,[reverse/1]).
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

% Remove Spaces from string
removeSpaces(String) ->
    re:replace(String, "\s", "", [global,{return,list}]).

% Removes the tail of a list 
removeTail({H,_T}) ->
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

% Wrapper for the parse function as this removes all spacing, then calls the actual parse function
% Takes a string of characters that represents an equation and returns it parsed. 
parse(Line, Rev) -> 
    NewLine = removeSpaces(Line),
    Stack = parseShun(NewLine,[],[]),
    % io:format("NewStack ~p~n", [Stack]),
    Infix = convertToString(lists:reverse(Stack), [], Rev),
    % io:format("New Exp ~p~n", [Infix]),
    parse2(Infix).

% precedence takes a string of a operator, and returns its precedence as a int for comparsion 
-spec precedence(string()) -> integer().

% Val is the precedence of the operator to get 
precedence(Val) ->
    case Val of
      "+" -> 1;
	  "*" -> 2;
      "%" -> 2;
      "#" -> 2;
       $+ -> 1;
	   $* -> 2;
       $% -> 2;
       $# -> 2;
       "(" -> 3 
    end.

% Represents a output stack which will be used to read from 
-type outStack() :: [string()].

% Represents a operator stack which will hold out operators during parsing 
-type opStack() :: [string()]. 

% Pops off operators until it hits a "("
% string() - Current operator to be added to stack
% outStack() - Output stack for the result
% opStack() - Operator stack
% Returns the new outStack and opStack modified 
-spec popOps(string(), outStack(), opStack()) -> {outStack(), opStack()}.

% When at the end add the operator to the opStack
popOps(Ch, OutStack, []) ->
    {OutStack, [Ch]};

% If precedence is not a "(" or a bigger operator then pop off current head 
popOps(Ch, OutStack, [OpH|OpT]) ->
    Head = precedence(OpH),
    Op = precedence(Ch),
    if 
        (Head =/= 3 andalso Op =< Head) -> popOps(Ch, [OpH|OutStack], OpT);
        true -> {OutStack, [Ch, OpH|OpT]}
    end.

% Pops operators off the stack and into the OutStack until it hits a "("
-spec popPar(outStack(), opStack()) -> {outStack(), opStack()}.

% Pop parenthese off if found, return new opStack
popPar(OutStack, [OpH|OpT]) -> 
    if 
        OpH == "(" -> {OutStack, OpT};
        true -> popPar([OpH|OutStack], OpT)
    end.

% Parses a string into a stack in postfix order with operator precedence
% Call using string() as expression, outStack and opStack as []. Returns the finished outStack
-spec parseShun(string(), outStack(), opStack()) -> [string()].

% if number add to output stack 
parseShun([Ch|Rest], OutStack, OpStack) when ($0 =< Ch andalso Ch =< $9) orelse Ch==$- ->
    {Succeeds,Remainder} = get_while(fun is_digit/1,Rest),
    Num = [Ch|Succeeds],
    NewOut = [Num|OutStack],
    parseShun(Remainder, NewOut, OpStack);

% If variable add to output stack
parseShun([Ch|Rest], OutStack, OpStack)  when $a =< Ch andalso Ch =< $z ->
    {Succeeds,Remainder} = get_while(fun is_alpha/1,Rest),
    Var = [Ch|Succeeds],
    NewOut = [Var|OutStack],
    parseShun(Remainder, NewOut, OpStack);

% If Operator is "(" then add to operator stack
parseShun([$(|Rest], OutStack, OpStack) ->
    parseShun(Rest, OutStack, ["("|OpStack]);

% If Operator is ")" for every op before "(" add to stack
parseShun([$)|Rest], OutStack, OpStack) ->
    {NewOutStack, NewOpStack} = popPar(OutStack, OpStack),
    parseShun(Rest, NewOutStack, NewOpStack);

% If Operator is +, *, #, or %, check precedence before adding to OpStack
parseShun([Ch|Rest], OutStack, OpStack) when ((Ch == $* orelse Ch == $#) orelse (Ch == $+ orelse Ch == $%)) ->
    {NewOutStack, NewOpStack} = popOps(Ch,OutStack,OpStack),
    parseShun(Rest, NewOutStack, NewOpStack);

% If OpStack is empty and the Ch is a Operator, add it to OpStack
parseShun([Ch|Rest], Output, []) when ((Ch == $+ orelse Ch == $-) orelse $( == Ch) ->
    parseShun(Rest, Output, [Ch]);

% Nothing left return the outStack 
parseShun([], OutStack, []) ->
    OutStack;

% If End of string, pop everything to OutStack
parseShun([], OutStack, OpStack) ->
    [OpStack|OutStack].

% Holds a list of strings that represent the final infix notation of the outStack 
-type numStack() :: [string()].

%REMEBER TO REVERSE LIST BEFORE CALLING THIS
% Converts the OutStack from the Shunting algorithom into a string, with correct "()"
% integer() - Reverses the order if 1, 0 to not reverse 
-spec convertToString(outStack(), numStack(), integer()) -> string().

convertToString([], [H|_T], _Rev) -> H;

% convertToString([], NumStack) -> NumStack;

% If a number add to NumStack
convertToString([H|Rest], NumStack, Rev) when ((H =/= $* andalso H =/= $#) andalso (H =/= $+ andalso H =/= $%)) ->
    % io:format("Done ~p~n", [H]),
    convertToString(Rest, [H|NumStack], Rev);

% If operator then pop next two numbers and add parentheses 
convertToString([H|Rest], [N1, N2 | Tail], Rev) when H == $* ->
    NewString = "(" ++ N1 ++ "*" ++ N2 ++ ")",
    if 
        Rev =:= 1 -> convertToString(Rest, ["(" ++ N2 ++ "*" ++ N1 ++ ")" | Tail], Rev);
        true -> convertToString(Rest, [NewString | Tail], Rev)
    end;
    
% If current element is a +, add N1 and N2
convertToString([H|Rest], [N1, N2 | Tail], Rev) when H == $+ ->
    NewString = "(" ++ N1 ++ "+" ++ N2 ++ ")",
    if 
        Rev =:= 1 -> convertToString(Rest, ["(" ++ N2 ++ "+" ++ N1 ++ ")" | Tail], Rev);
        true -> convertToString(Rest, [NewString | Tail], Rev)
    end;
    
% If current element is a #, divide N1 and N2
convertToString([H|Rest], [N1, N2 | Tail], Rev) when H == $# ->
    NewString = "(" ++ N1 ++ "#" ++ N2 ++ ")",
    if 
        Rev =:= 1 -> convertToString(Rest, ["(" ++ N2 ++ "#" ++ N1 ++ ")" | Tail], Rev);
        true -> convertToString(Rest, [NewString | Tail], Rev)
    end;
    
% If current element is a %, rem N1 and N2
convertToString([H|Rest], [N1, N2 | Tail], Rev) when H == $% ->
    NewString = "(" ++ N1 ++ "%" ++ N2 ++ ")",
    if 
        Rev =:= 1 -> convertToString(Rest, ["(" ++ N2 ++ "%" ++ N1 ++ ")" | Tail], Rev);
        true -> convertToString(Rest, [NewString | Tail], Rev)
    end.
    

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
% [] is a list of strings to parse
% _Rev is Reverse: 1 to reverse 0 to not
parseLines([], _Rev) -> [];

parseLines([H | T], Rev) ->
    Parsed = parse(H, Rev),
    Expr = removeTail(Parsed),
    [Expr | parseLines(T, Rev)].

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

% Execute multiple lines of a list of expressions, uses the default environment given
-spec executeLines([expr()]) -> [integer()].

executeLines([]) -> [];

executeLines([H | T]) ->
    Val = execute([{a,23},{b,-12}], H),
    [integer_to_list(Val) | executeLines(T)].

% RUNNING THE PROGRAM
% Runs the program using eval method and writes output
mymain1() ->
    receive
        start ->
        Lines = readlines("expressions.txt"),
        Parsed = parseLines(Lines, 1),
        Values = evalLines(Parsed),
        Text = [string:join(Values, io_lib:nl()), io_lib:nl()],
        write_file("./output.txt", Text);
        stop -> true
    end.

mymain2() ->
    receive 
        start ->
        Lines = readlines("expressions.txt"),
        Parsed = parseLines(Lines, 0),
        Values = executeLines(Parsed),
        Text = [string:join(Values, io_lib:nl()), io_lib:nl()],
        write_file("./output2.txt", Text);
        stop -> true
    end.

go() -> 
    % Spawn two children for the two mains 
    register(parent, self()),

    Pid = spawn(pr2, mymain1, []),
    Pid2 = spawn(pr2, mymain2, []),

    register(child1, Pid), 
    register(child2, Pid2),

    child1 ! start,
    child2 ! start,
    child1 ! stop, 
    child2 ! stop, 
    unregister(parent),
    unregister(child1),
    unregister(child2).

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
	     
