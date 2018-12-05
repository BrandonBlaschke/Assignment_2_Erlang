-module(pr2_tests).
-include_lib("eunit/include/eunit.hrl").

% Remove Space Tests
removeSpace1_test() ->
    true = pr2:removeSpaces("( 5 + 5 )") =:= "(5+5)".

removeSpace2_test() ->
    true = pr2:removeSpaces("( 5 * (5 + 2)     )") =:= "(5*(5+2))".

removeSpace3_test() ->
    true = pr2:removeSpaces("       ") =:= "".

removeSpace4_test() ->
    true = pr2:removeSpaces("(5+5*(3+2)") =:= "(5+5*(3+2)".

removeSpace5_test() ->
    true = pr2:removeSpaces("((5+5) + (6%2))") =:= "((5+5)+(6%2))".

% Parse mod 
praseMod1_test() ->
    P = pr2:parse2("(5%5)"),
    true = P =:= {{mod,{num,5},{num,5}},[]}.

praseMod2_test() ->
    P = pr2:parse2("((5%5)%3)"),
    true = P =:= {{mod,{mod,{num,5},{num,5}},{num,3}},[]}.

praseMod3_test() ->
    P = pr2:parse2("((5*5)%3)"),
    true = P =:= {{mod,{mul,{num,5},{num,5}},{num,3}},[]}.

praseMod4_test() ->
    P = pr2:parse2("((5+5)%3)"),
    true = P =:= {{mod,{add,{num,5},{num,5}},{num,3}},[]}.

praseMod5_test() ->
    P = pr2:parse2("((5#5)%3)"),
    true = P =:= {{mod,{idiv,{num,5},{num,5}},{num,3}},[]}.

% Parse idiv
parseDiv1_test() ->
    P = pr2:parse2("(5#5)"),
    true = P =:= {{idiv,{num,5},{num,5}},[]}.

parseDiv2_test() ->
    P = pr2:parse2("(1+(5#5))"),
    true = P =:= {{add,{num,1},{idiv,{num,5},{num,5}}},[]}.

parseDiv3_test() ->
    P = pr2:parse2("(1*(5#5))"),
    true = P =:= {{mul,{num,1},{idiv,{num,5},{num,5}}},[]}.

parseDiv4_test() ->
    P = pr2:parse2("(1%(5#5))"),
    true = P =:= {{mod,{num,1},{idiv,{num,5},{num,5}}},[]}.

parseDiv5_test() ->
    P = pr2:parse2("(1#(5#5))"),
    true = P =:= {{idiv,{num,1},{idiv,{num,5},{num,5}}},[]}.

% Eval idiv 
evalDiv1_test() ->
    true = pr2:eval([{a,23},{b,-12}], {idiv,{num,5},{num,5}}) == 1.

evalDiv2_test() ->
    true = pr2:eval([{a,23},{b,-12}], {idiv,{num,2},{num,5}}) == 0.

evalDiv3_test() ->
    true = pr2:eval([{a,23},{b,-12}], {idiv,{num,10},{num,5}}) == 2.

evalDiv4_test() ->
    true = pr2:eval([{a,23},{b,-12}], {idiv,{num,0},{num,1}}) == 0.

evalDiv5_test() ->
    true = pr2:eval([{a,23},{b,-12}], {mod,{num,1},{idiv,{num,5},{num,5}}}) == 0.

% Eval mod 
evalMod1_test() ->
    true = pr2:eval([{a,23},{b,-12}],{mod,{num,5},{num,5}}) == 0.

evalMod2_test() ->
    true = pr2:eval([{a,23},{b,-12}],{mod,{num,11},{num,5}}) == 1.

evalMod3_test() ->
    true = pr2:eval([{a,23},{b,-12}],{mod,{num,0},{num,5}}) == 0.

evalMod4_test() ->
    true = pr2:eval([{a,23},{b,-12}],{mod,{num,-5},{num,5}}) == 0.

evalMod5_test() ->
    true = pr2:eval([{a,23},{b,-12}],{mod,{idiv,{num,5},{num,5}},{num,3}}) == 1.

% Execute Test
exe1_test() -> 
    true = pr2:execute([{a,23},{b,-12}], {mod,{num,5},{num,5}}) == 0.

exe2_test() ->
    true = pr2:execute([{a,23},{b,-12}], {mod,{num,5},{num,11}}) == 1.

exe3_test() -> 
    true = pr2:execute([{a,23},{b,-12}], {mod,{num,5},{num,0}}) == 0.

exe4_test() -> 
    true = pr2:execute([{a,23},{b,-12}], {mod,{num,5},{num,-5}}) == 0.

exe5_test() -> 
    true = pr2:execute([{a,23},{b,-12}], {mod,{idiv,{num,3},{num,5}},{num,5}}) == 0.

exe6_test() -> 
    true = pr2:execute([{a,23},{b,-12}], {mod,{num,1},{idiv,{num,5},{num,5}}}) == 0.

exe7_test() -> 
    true = pr2:execute([{a,23},{b,-12}], {idiv,{num,1},{num,0}}) == 0.

exe8_test() -> 
    true = pr2:execute([{a,23},{b,-12}], {idiv,{num,5},{num,10}}) == 2.

% Shunting Algorithm Tests, ASCII values for Operators are below
% 42 = *
% 43 = +
% 37 = %
% 35 = #
shun1_test() ->
    true = pr2:parseShun("(5+5*3)", [], []) == [43,42,"3","5","5"].

shun2_test() ->
    true = pr2:parseShun("(5+5%3)", [], []) == [43,37,"3","5","5"].

shun3_test() ->
    true = pr2:parseShun("(5+5#3)", [], []) == [43,35,"3","5","5"].

shun4_test() ->
    true = pr2:parseShun("(5+5%3*b)", [], []) == [43,42,"b",37,"3","5","5"].

shun5_test() ->
    true = pr2:parseShun("((2+4)*(3%a))", [], []) == [42,37,"a","3",43,"4","2"].

%  Convert to string tests 
toString1_test() -> 
    true = pr2:convertToString(["5","5","3", 42, 43], [], 1) == "(5+(5*3))".

toString2_test() -> 
    true = pr2:convertToString(["5","5","3", 37, 43], [], 1) == "(5+(5%3))".

toString3_test() -> 
    true = pr2:convertToString(["5","5","3", 35, 43], [], 1) == "(5+(5#3))".

toString4_test() -> 
    true = pr2:convertToString(["5","5","3", 37, "a", 42, 43], [], 1) == "(5+((5%3)*a))".

toString5_test() -> 
    true = pr2:convertToString(["5","5","3", 37, "4", 42, 43], [], 0) == "((4*(3%5))+5)".

toString6_test() ->
    true = pr2:convertToString(["b", "4", 43, "3", "3", 37, 42], [], 1) == "((b+4)*(3%3))".

% Precendence Tests 
prec1_test() ->
    true = pr2:precedence("+") =:= 1.

prec2_test() ->
    true = pr2:precedence("#") =:= 2.

prec3_test() ->
    true = pr2:precedence("%") =:= 2.

prec4_test() ->
    true = pr2:precedence("*") =:= 2.

prec5_test() ->
    true = pr2:precedence("(") =:= 3.