-module(google_ip).
-export([test/1]).

test(File) ->
	statistics(runtime),
	statistics(wall_clock),
	%% ip list
	{ok, Fd} = file:open(File, read),
	Ip_list = parse_ip(Fd),
	file:close(Fd),
	inets:start(),
	Ok_list = test_list(Ip_list, 0, 5),
	unconsult("data/ok_list", Ok_list),
	{_, Runtime} = statistics(runtime),
	{_, Wall_clock} = statistics(wall_clock),
	io:format("cpu time: ~p~nreal time: ~p~n", [Runtime, Wall_clock]).

%% test a ip list for several times
test_list(Ip_list, N, N) -> 
	io:format("ok list: ~p~n", [length(Ip_list)]),
	Ip_list;

test_list(Ip_list, I, N) ->
	io:format("Step ~p. list length: ~p~n", [I, length(Ip_list)]),
	Pid = self(),
	Wait_pid = spawn(fun() -> wait_result(length(Ip_list), Pid) end),
	lists:foreach(fun(Ip) -> spawn(fun() -> test_ip(Wait_pid, Ip) end) end, Ip_list),
	receive
		Ok_list -> test_list(Ok_list, I + 1, N)
	end.

%% test a ip
test_ip(Pid, Ip) ->
	case ping(Ip) of
		true -> Pid ! {ok, Ip};
		false -> Pid ! {failed, Ip}
	end.

ping(Ip) ->
	case httpc:request(get, {Ip, []}, [{timeout, timer:seconds(5)}], []) of
		{ok, _} -> true;
		_ -> false
	end.


%% write List to File
unconsult(File, List) ->
	{ok, Fd} = file:open(File, write),
	lists:foreach(fun(X) -> io:format(Fd, "~p~n", [X]) end, List),
	file:close(Fd).

%% a proc waiting for result
wait_result(Max, Pid) -> wait_result([], [], 0, Max, Pid).

wait_result(Ok_list, _Fail_list, Max, Max, Pid) -> 
	Pid ! Ok_list;

wait_result(Ok_list, Fail_list, Len, Max, Pid) ->
	receive 
		{ok, Ip}     -> wait_result([Ip | Ok_list], Fail_list, Len + 1, Max, Pid);
		{failed, Ip} -> wait_result(Ok_list, [Ip | Fail_list], Len + 1, Max, Pid)
	end.


%% parse ip list from file
parse_ip(Fd) -> parse_ip(Fd, []).

parse_ip(Fd, Ip_list) ->
	case io:get_line(Fd, '') of
		eof -> Ip_list;
		Line  -> 
			Ip = string:substr(Line, 1, length(Line) - 1),
			parse_ip(Fd, [Ip | Ip_list])
	end.

