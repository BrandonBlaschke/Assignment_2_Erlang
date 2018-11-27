-module(expr_main).

-compile(export_all).

-import(expr, []).

% uses evaluation without compiler / VM
mymain1() ->
    {Ex, _} = expr:parse("(2*(3+4))"),
    expr:eval([], Ex).

% uses evaluation without compiler / VM
mymain2() ->
    Env = [{x, 5}, {y, 7}], 
    {Ex, _} = expr:parse("((x+1)*y)"),
    expr:eval(Env, Ex).

% uses evaluation without compiler / VM
mymain3() ->
    expr:eval(expr:env1(), expr:expr1()).

% uses evaluation with compiler / VM
mymain4() ->
    {Ex, _} = expr:parse("(2*(3+4))"),
    expr:execute([], Ex).

% uses evaluation with compiler / VM
mymain5() ->
    Env = [{x, 5}, {y, 7}], 
    {Ex, _} = expr:parse("((x+1)*y)"),
    expr:execute(Env, Ex).

% uses evaluation without compiler / VM
mymain6() ->
    expr:execute(expr:env1(), expr:expr1()).

% tests reverse of parsing = "pretty printing"
mymain7() ->
    {Ex, _} = expr:parse("(2*(3+4))"),
    expr:print(Ex).

% tests reverse of parsing = "pretty printing"
mymain8() ->
    {Ex, _} = expr:parse("((x+1)*y)"),
    expr:print(Ex).

% tests reverse of parsing = "pretty printing"
mymain9() ->
    expr:print(expr:expr1()).

% shows file reading / writing
readwrite() ->
  {ok, Input} = file:open("expressions.txt", read),
  {ok, Output} = file:open("output.txt", write),
  parseFile(Input, Output),
  file:close(Input),
  file:close(Output).

% read / write helper
parseFile(Input, Output) ->
  Line = io:get_line(Input, ""),
  if
    Line =/= eof ->
      file:write(Output, Line),
      parseFile(Input, Output);
    true -> pass
  end.
