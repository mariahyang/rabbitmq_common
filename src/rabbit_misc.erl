%%   The contents of this file are subject to the Mozilla Public License
%%   Version 1.1 (the "License"); you may not use this file except in
%%   compliance with the License. You may obtain a copy of the License at
%%   http://www.mozilla.org/MPL/
%%
%%   Software distributed under the License is distributed on an "AS IS"
%%   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%%   License for the specific language governing rights and limitations
%%   under the License.
%%
%%   The Original Code is RabbitMQ.
%%
%%   The Initial Developers of the Original Code are LShift Ltd,
%%   Cohesive Financial Technologies LLC, and Rabbit Technologies Ltd.
%%
%%   Portions created before 22-Nov-2008 00:00:00 GMT by LShift Ltd,
%%   Cohesive Financial Technologies LLC, or Rabbit Technologies Ltd
%%   are Copyright (C) 2007-2008 LShift Ltd, Cohesive Financial
%%   Technologies LLC, and Rabbit Technologies Ltd.
%%
%%   Portions created by LShift Ltd are Copyright (C) 2007-2010 LShift
%%   Ltd. Portions created by Cohesive Financial Technologies LLC are
%%   Copyright (C) 2007-2010 Cohesive Financial Technologies
%%   LLC. Portions created by Rabbit Technologies Ltd are Copyright
%%   (C) 2007-2010 Rabbit Technologies Ltd.
%%
%%   All Rights Reserved.
%%
%%   Contributor(s): ______________________________________.
%%

-module(rabbit_misc).
-include("rabbit.hrl").
-include("rabbit_framing.hrl").

-include_lib("kernel/include/file.hrl").

-export([method_record_type/1, polite_pause/0, polite_pause/1]).
-export([die/1, frame_error/2, amqp_error/4,
         protocol_error/3, protocol_error/4, protocol_error/1]).
-export([not_found/1, assert_args_equivalence/4]).
-export([dirty_read/1]).
-export([table_lookup/2]).
-export([r/3, r/2, r_arg/4, rs/1]).
-export([enable_cover/0, report_cover/0]).
-export([enable_cover/1, report_cover/1]).
-export([start_cover/1]).
-export([throw_on_error/2, with_exit_handler/2, filter_exit_map/2]).
-export([with_user/2, with_vhost/2, with_user_and_vhost/3]).
-export([execute_mnesia_transaction/1]).
-export([ensure_ok/2]).
-export([makenode/1, nodeparts/1, cookie_hash/0, tcp_name/3]).
-export([intersperse/2, upmap/2, map_in_order/2]).
-export([table_fold/3]).
-export([dirty_read_all/1, dirty_foreach_key/2, dirty_dump_log/1]).
-export([read_term_file/1, write_term_file/2]).
-export([append_file/2, ensure_parent_dirs_exist/1]).
-export([format_stderr/2]).
-export([start_applications/1, stop_applications/1]).
-export([unfold/2, ceil/1, queue_fold/3]).
-export([sort_field_table/1]).
-export([pid_to_string/1, string_to_pid/1]).
-export([version_compare/2, version_compare/3]).
-export([recursive_delete/1, dict_cons/3, orddict_cons/3,
         unlink_and_capture_exit/1]).
-export([get_options/2]).

-import(mnesia, [dirty_next/2, dirty_first/1, match_object/3, dirty_select/2]).
-import(lists, [foldl/3, foreach/2, foldr/3, flatten/1, append/3, splitwith/2, dropwhile/2, keysort/2, reverse/1, filter/2, keysearch/3, sort/2]).
-import(cover, [modules/0, analyze_to_file/3, analyze/2, start/1, compile_beam_directory/1]).
-import(disk_log, [chunk/2, open/3, close/1]).

%%----------------------------------------------------------------------------

-ifdef(use_specs).

-export_type([resource_name/0]).

-type(ok_or_error() :: rabbit_types:ok_or_error(any())).
-type(thunk(T) :: fun(() -> T)).
-type(resource_name() :: binary()).
-type(optdef() :: {flag, string()} | {option, string(), any()}).
-type(channel_or_connection_exit()
      :: rabbit_types:channel_exit() | rabbit_types:connection_exit()).

-spec(method_record_type/1 :: (rabbit_framing:amqp_method_record())
                              -> rabbit_framing:amqp_method_name()).
-spec(polite_pause/0 :: () -> 'done').
-spec(polite_pause/1 :: (non_neg_integer()) -> 'done').
-spec(die/1 ::
        (rabbit_framing:amqp_exception()) -> channel_or_connection_exit()).
-spec(frame_error/2 :: (rabbit_framing:amqp_method_name(), binary())
                       -> rabbit_types:connection_exit()).
-spec(amqp_error/4 ::
        (rabbit_framing:amqp_exception(), string(), [any()],
         rabbit_framing:amqp_method_name())
        -> rabbit_types:amqp_error()).
-spec(protocol_error/3 :: (rabbit_framing:amqp_exception(), string(), [any()])
                          -> channel_or_connection_exit()).
-spec(protocol_error/4 ::
        (rabbit_framing:amqp_exception(), string(), [any()],
         rabbit_framing:amqp_method_name()) -> channel_or_connection_exit()).
-spec(protocol_error/1 ::
        (rabbit_types:amqp_error()) -> channel_or_connection_exit()).
-spec(not_found/1 :: (rabbit_types:r(atom())) -> rabbit_types:channel_exit()).
-spec(assert_args_equivalence/4 :: (rabbit_framing:amqp_table(),
                                    rabbit_framing:amqp_table(),
                                    rabbit_types:r(any()), [binary()]) ->
                                        'ok' | rabbit_types:connection_exit()).
-spec(dirty_read/1 ::
        ({atom(), any()}) -> rabbit_types:ok_or_error2(any(), 'not_found')).
-spec(table_lookup/2 ::
        (rabbit_framing:amqp_table(), binary())
         -> 'undefined' | {rabbit_framing:amqp_field_type(), any()}).
-spec(r/2 :: (rabbit_types:vhost(), K)
             -> rabbit_types:r3(rabbit_types:vhost(), K, '_')
                    when is_subtype(K, atom())).
-spec(r/3 ::
        (rabbit_types:vhost() | rabbit_types:r(atom()), K, resource_name())
        -> rabbit_types:r3(rabbit_types:vhost(), K, resource_name())
               when is_subtype(K, atom())).
-spec(r_arg/4 ::
        (rabbit_types:vhost() | rabbit_types:r(atom()), K,
         rabbit_framing:amqp_table(), binary())
        -> undefined | rabbit_types:r(K)
               when is_subtype(K, atom())).
-spec(rs/1 :: (rabbit_types:r(atom())) -> string()).
-spec(enable_cover/0 :: () -> ok_or_error()).
-spec(start_cover/1 :: ([{string(), string()} | string()]) -> 'ok').
-spec(report_cover/0 :: () -> 'ok').
-spec(enable_cover/1 :: (file:filename()) -> ok_or_error()).
-spec(report_cover/1 :: (file:filename()) -> 'ok').
-spec(throw_on_error/2 ::
        (atom(), thunk(rabbit_types:error(any()) | {ok, A} | A)) -> A).
-spec(with_exit_handler/2 :: (thunk(A), thunk(A)) -> A).
-spec(filter_exit_map/2 :: (fun ((A) -> B), [A]) -> [B]).
-spec(with_user/2 :: (rabbit_access_control:username(), thunk(A)) -> A).
-spec(with_vhost/2 :: (rabbit_types:vhost(), thunk(A)) -> A).
-spec(with_user_and_vhost/3 ::
        (rabbit_access_control:username(), rabbit_types:vhost(), thunk(A))
        -> A).
-spec(execute_mnesia_transaction/1 :: (thunk(A)) -> A).
-spec(ensure_ok/2 :: (ok_or_error(), atom()) -> 'ok').
-spec(makenode/1 :: ({string(), string()} | string()) -> node()).
-spec(nodeparts/1 :: (node() | string()) -> {string(), string()}).
-spec(cookie_hash/0 :: () -> string()).
-spec(tcp_name/3 ::
        (atom(), inet:ip_address(), rabbit_networking:ip_port())
        -> atom()).
-spec(intersperse/2 :: (A, [A]) -> [A]).
-spec(upmap/2 :: (fun ((A) -> B), [A]) -> [B]).
-spec(map_in_order/2 :: (fun ((A) -> B), [A]) -> [B]).
-spec(table_fold/3 :: (fun ((any(), A) -> A), A, atom()) -> A).
-spec(dirty_read_all/1 :: (atom()) -> [any()]).
-spec(dirty_foreach_key/2 :: (fun ((any()) -> any()), atom())
                             -> 'ok' | 'aborted').
-spec(dirty_dump_log/1 :: (file:filename()) -> ok_or_error()).
-spec(read_term_file/1 ::
        (file:filename()) -> {'ok', [any()]} | rabbit_types:error(any())).
-spec(write_term_file/2 :: (file:filename(), [any()]) -> ok_or_error()).
-spec(append_file/2 :: (file:filename(), string()) -> ok_or_error()).
-spec(ensure_parent_dirs_exist/1 :: (string()) -> 'ok').
-spec(format_stderr/2 :: (string(), [any()]) -> 'ok').
-spec(start_applications/1 :: ([atom()]) -> 'ok').
-spec(stop_applications/1 :: ([atom()]) -> 'ok').
-spec(unfold/2  :: (fun ((A) -> ({'true', B, A} | 'false')), A) -> {[B], A}).
-spec(ceil/1 :: (number()) -> integer()).
-spec(queue_fold/3 :: (fun ((any(), B) -> B), B, queue()) -> B).
-spec(sort_field_table/1 ::
        (rabbit_framing:amqp_table()) -> rabbit_framing:amqp_table()).
-spec(pid_to_string/1 :: (pid()) -> string()).
-spec(string_to_pid/1 :: (string()) -> pid()).
-spec(version_compare/2 :: (string(), string()) -> 'lt' | 'eq' | 'gt').
-spec(version_compare/3 ::
        (string(), string(), ('lt' | 'lte' | 'eq' | 'gte' | 'gt'))
        -> boolean()).
-spec(recursive_delete/1 ::
        ([file:filename()])
        -> rabbit_types:ok_or_error({file:filename(), any()})).
-spec(dict_cons/3 :: (any(), any(), dict:dictionary()) ->
                          dict:dictionary()).
-spec(orddict_cons/3 :: (any(), any(), orddict:dictionary()) ->
                             orddict:dictionary()).
-spec(unlink_and_capture_exit/1 :: (pid()) -> 'ok').
-spec(get_options/2 :: ([optdef()], [string()])
                       -> {[string()], [{string(), any()}]}).

-endif.

%%----------------------------------------------------------------------------

method_record_type(Record) ->
    element(1, Record).

polite_pause() ->
    polite_pause(3000).

polite_pause(N) ->
    receive
    after N -> done
    end.

die(Error) ->
    protocol_error(Error, "~w", [Error]).

frame_error(MethodName, BinaryFields) ->
    protocol_error(frame_error, "cannot decode ~w", [BinaryFields], MethodName).

amqp_error(Name, ExplanationFormat, Params, Method) ->
    Explanation = lists:flatten(io_lib:format(ExplanationFormat, Params)),
    #amqp_error{name = Name, explanation = Explanation, method = Method}.

protocol_error(Name, ExplanationFormat, Params) ->
    protocol_error(Name, ExplanationFormat, Params, none).

protocol_error(Name, ExplanationFormat, Params, Method) ->
    protocol_error(amqp_error(Name, ExplanationFormat, Params, Method)).

protocol_error(#amqp_error{} = Error) ->
    exit(Error).

not_found(R) -> protocol_error(not_found, "no ~s", [rs(R)]).

assert_args_equivalence(Orig, New, Name, Keys) ->
    [assert_args_equivalence1(Orig, New, Name, Key) || Key <- Keys],
    ok.

assert_args_equivalence1(Orig, New, Name, Key) ->
    case {table_lookup(Orig, Key), table_lookup(New, Key)} of
        {Same, Same}  -> ok;
        {Orig1, New1} -> protocol_error(
                           not_allowed,
                           "inequivalent arg '~s' for ~s:  "
                           "required ~w, received ~w",
                           [Key, rabbit_misc:rs(Name), New1, Orig1])
    end.

dirty_read(ReadSpec) ->
    case mnesia:dirty_read(ReadSpec) of
        [Result] -> {ok, Result};
        []       -> {error, not_found}
    end.

table_lookup(Table, Key) ->
    case lists:keysearch(Key, 1, Table) of
        {value, {_, TypeBin, ValueBin}} -> {TypeBin, ValueBin};
        false                           -> undefined
    end.

r(#resource{virtual_host = VHostPath}, Kind, Name)
  when is_binary(Name) ->
    #resource{virtual_host = VHostPath, kind = Kind, name = Name};
r(VHostPath, Kind, Name) when is_binary(Name) andalso is_binary(VHostPath) ->
    #resource{virtual_host = VHostPath, kind = Kind, name = Name}.

r(VHostPath, Kind) when is_binary(VHostPath) ->
    #resource{virtual_host = VHostPath, kind = Kind, name = '_'}.

r_arg(#resource{virtual_host = VHostPath}, Kind, Table, Key) ->
    r_arg(VHostPath, Kind, Table, Key);
r_arg(VHostPath, Kind, Table, Key) ->
    case table_lookup(Table, Key) of
        {longstr, NameBin} -> r(VHostPath, Kind, NameBin);
        undefined          -> undefined
    end.

rs(#resource{virtual_host = VHostPath, kind = Kind, name = Name}) ->
    lists:flatten(io_lib:format("~s '~s' in vhost '~s'",
                                [Kind, Name, VHostPath])).

enable_cover() ->
    enable_cover(".").

enable_cover([Root]) when is_atom(Root) ->
    enable_cover(atom_to_list(Root));
enable_cover(Root) ->
    case cover:compile_beam_directory(filename:join(Root, "ebin")) of
        {error,Reason} -> {error,Reason};
        _ -> ok
    end.

start_cover(NodesS) ->
    {ok, _} = cover:start([makenode(N) || N <- NodesS]),
    ok.

report_cover() ->
    report_cover(".").

report_cover([Root]) when is_atom(Root) ->
    report_cover(atom_to_list(Root));
report_cover(Root) ->
    Dir = filename:join(Root, "cover"),
    ok = filelib:ensure_dir(filename:join(Dir,"junk")),
    lists:foreach(fun (F) -> file:delete(F) end,
                  filelib:wildcard(filename:join(Dir, "*.html"))),
    {ok, SummaryFile} = file:open(filename:join(Dir, "summary.txt"), [write]),
    {CT, NCT} =
        lists:foldl(
          fun (M,{CovTot, NotCovTot}) ->
                  {ok, {M, {Cov, NotCov}}} = cover:analyze(M, module),
                  ok = report_coverage_percentage(SummaryFile,
                                                  Cov, NotCov, M),
                  {ok,_} = cover:analyze_to_file(
                             M,
                             filename:join(Dir, atom_to_list(M) ++ ".html"),
                             [html]),
                  {CovTot+Cov, NotCovTot+NotCov}
          end,
          {0, 0},
          lists:sort(cover:modules())),
    ok = report_coverage_percentage(SummaryFile, CT, NCT, 'TOTAL'),
    ok = file:close(SummaryFile),
    ok.

report_coverage_percentage(File, Cov, NotCov, Mod) ->
    io:fwrite(File, "~6.2f ~p~n",
              [if
                   Cov+NotCov > 0 -> 100.0*Cov/(Cov+NotCov);
                   true -> 100.0
               end,
               Mod]).

throw_on_error(E, Thunk) ->
    case Thunk() of
        {error, Reason} -> throw({E, Reason});
        {ok, Res}       -> Res;
        Res             -> Res
    end.

with_exit_handler(Handler, Thunk) ->
    try
        Thunk()
    catch
        exit:{R, _} when R =:= noproc; R =:= normal; R =:= shutdown ->
            Handler()
    end.

filter_exit_map(F, L) ->
    Ref = make_ref(),
    lists:filter(fun (R) -> R =/= Ref end,
                 [with_exit_handler(
                    fun () -> Ref end,
                    fun () -> F(I) end) || I <- L]).

with_user(Username, Thunk) ->
    fun () ->
            case mnesia:read({rabbit_user, Username}) of
                [] ->
                    mnesia:abort({no_such_user, Username});
                [_U] ->
                    Thunk()
            end
    end.

with_vhost(VHostPath, Thunk) ->
    fun () ->
            case mnesia:read({rabbit_vhost, VHostPath}) of
                [] ->
                    mnesia:abort({no_such_vhost, VHostPath});
                [_V] ->
                    Thunk()
            end
    end.

with_user_and_vhost(Username, VHostPath, Thunk) ->
    with_user(Username, with_vhost(VHostPath, Thunk)).


execute_mnesia_transaction(TxFun) ->
    %% Making this a sync_transaction allows us to use dirty_read
    %% elsewhere and get a consistent result even when that read
    %% executes on a different node.
    case worker_pool:submit({mnesia, sync_transaction, [TxFun]}) of
        {atomic,  Result} -> Result;
        {aborted, Reason} -> throw({error, Reason})
    end.

ensure_ok(ok, _) -> ok;
ensure_ok({error, Reason}, ErrorTag) -> throw({error, {ErrorTag, Reason}}).

makenode({Prefix, Suffix}) ->
    list_to_atom(lists:append([Prefix, "@", Suffix]));
makenode(NodeStr) ->
    makenode(nodeparts(NodeStr)).

nodeparts(Node) when is_atom(Node) ->
    nodeparts(atom_to_list(Node));
nodeparts(NodeStr) ->
    case lists:splitwith(fun (E) -> E =/= $@ end, NodeStr) of
        {Prefix, []}     -> {_, Suffix} = nodeparts(node()),
                            {Prefix, Suffix};
        {Prefix, Suffix} -> {Prefix, tl(Suffix)}
    end.

cookie_hash() ->
    base64:encode_to_string(erlang:md5(atom_to_list(erlang:get_cookie()))).

tcp_name(Prefix, IPAddress, Port)
  when is_atom(Prefix) andalso is_number(Port) ->
    list_to_atom(
      lists:flatten(
        io_lib:format("~w_~s:~w",
                      [Prefix, inet_parse:ntoa(IPAddress), Port]))).

intersperse(_, []) -> [];
intersperse(_, [E]) -> [E];
intersperse(Sep, [E|T]) -> [E, Sep | intersperse(Sep, T)].

%% This is a modified version of Luke Gorrie's pmap -
%% http://lukego.livejournal.com/6753.html - that doesn't care about
%% the order in which results are received.
%%
%% WARNING: This is is deliberately lightweight rather than robust -- if F
%% throws, upmap will hang forever, so make sure F doesn't throw!
upmap(F, L) ->
    Parent = self(),
    Ref = make_ref(),
    [receive {Ref, Result} -> Result end
     || _ <- [spawn(fun () -> Parent ! {Ref, F(X)} end) || X <- L]].

map_in_order(F, L) ->
    lists:reverse(
      lists:foldl(fun (E, Acc) -> [F(E) | Acc] end, [], L)).

%% Fold over each entry in a table, executing the cons function in a
%% transaction.  This is often far more efficient than wrapping a tx
%% around the lot.
%%
%% We ignore entries that have been modified or removed.
table_fold(F, Acc0, TableName) ->
    lists:foldl(
      fun (E, Acc) -> execute_mnesia_transaction(
                   fun () -> case mnesia:match_object(TableName, E, read) of
                                 [] -> Acc;
                                 _  -> F(E, Acc)
                             end
                   end)
      end, Acc0, dirty_read_all(TableName)).

dirty_read_all(TableName) ->
    mnesia:dirty_select(TableName, [{'$1',[],['$1']}]).

dirty_foreach_key(F, TableName) ->
    dirty_foreach_key1(F, TableName, mnesia:dirty_first(TableName)).

dirty_foreach_key1(_F, _TableName, '$end_of_table') ->
    ok;
dirty_foreach_key1(F, TableName, K) ->
    case catch mnesia:dirty_next(TableName, K) of
        {'EXIT', _} ->
            aborted;
        NextKey ->
            F(K),
            dirty_foreach_key1(F, TableName, NextKey)
    end.

dirty_dump_log(FileName) ->
    {ok, LH} = disk_log:open([{name, dirty_dump_log},
                              {mode, read_only},
                              {file, FileName}]),
    dirty_dump_log1(LH, disk_log:chunk(LH, start)),
    disk_log:close(LH).

dirty_dump_log1(_LH, eof) ->
    io:format("Done.~n");
dirty_dump_log1(LH, {K, Terms}) ->
    io:format("Chunk: ~p~n", [Terms]),
    dirty_dump_log1(LH, disk_log:chunk(LH, K));
dirty_dump_log1(LH, {K, Terms, BadBytes}) ->
    io:format("Bad Chunk, ~p: ~p~n", [BadBytes, Terms]),
    dirty_dump_log1(LH, disk_log:chunk(LH, K)).

read_term_file(File) -> file:consult(File).

write_term_file(File, Terms) ->
    file:write_file(File, list_to_binary([io_lib:format("~w.~n", [Term]) ||
                                             Term <- Terms])).

append_file(File, Suffix) ->
    case file:read_file_info(File) of
        {ok, FInfo}     -> append_file(File, FInfo#file_info.size, Suffix);
        {error, enoent} -> append_file(File, 0, Suffix);
        Error           -> Error
    end.

append_file(_, _, "") ->
    ok;
append_file(File, 0, Suffix) ->
    case file:open([File, Suffix], [append]) of
        {ok, Fd} -> file:close(Fd);
        Error    -> Error
    end;
append_file(File, _, Suffix) ->
    case file:read_file(File) of
        {ok, Data} -> file:write_file([File, Suffix], Data, [append]);
        Error      -> Error
    end.

ensure_parent_dirs_exist(Filename) ->
    case filelib:ensure_dir(Filename) of
        ok              -> ok;
        {error, Reason} ->
            throw({error, {cannot_create_parent_dirs, Filename, Reason}})
    end.

format_stderr(Fmt, Args) ->
    case os:type() of
        {unix, _} ->
            Port = open_port({fd, 0, 2}, [out]),
            port_command(Port, io_lib:format(Fmt, Args)),
            port_close(Port);
        {win32, _} ->
            %% stderr on Windows is buffered and I can't figure out a
            %% way to trigger a fflush(stderr) in Erlang. So rather
            %% than risk losing output we write to stdout instead,
            %% which appears to be unbuffered.
            io:format(Fmt, Args)
    end,
    ok.

manage_applications(Iterate, Do, Undo, SkipError, ErrorTag, Apps) ->
    Iterate(fun (App, Acc) ->
                    case Do(App) of
                        ok -> [App | Acc];
                        {error, {SkipError, _}} -> Acc;
                        {error, Reason} ->
                            lists:foreach(Undo, Acc),
                            throw({error, {ErrorTag, App, Reason}})
                    end
            end, [], Apps),
    ok.

start_applications(Apps) ->
    manage_applications(fun lists:foldl/3,
                        fun application:start/1,
                        fun application:stop/1,
                        already_started,
                        cannot_start_application,
                        Apps).

stop_applications(Apps) ->
    manage_applications(fun lists:foldr/3,
                        fun application:stop/1,
                        fun application:start/1,
                        not_started,
                        cannot_stop_application,
                        Apps).

unfold(Fun, Init) ->
    unfold(Fun, [], Init).

unfold(Fun, Acc, Init) ->
    case Fun(Init) of
        {true, E, I} -> unfold(Fun, [E|Acc], I);
        false -> {Acc, Init}
    end.

ceil(N) ->
    T = trunc(N),
    case N == T of
        true  -> T;
        false -> 1 + T
    end.

queue_fold(Fun, Init, Q) ->
    case queue:out(Q) of
        {empty, _Q}      -> Init;
        {{value, V}, Q1} -> queue_fold(Fun, Fun(V, Init), Q1)
    end.

%% Sorts a list of AMQP table fields as per the AMQP spec
sort_field_table(Arguments) ->
    lists:keysort(1, Arguments).

%% This provides a string representation of a pid that is the same
%% regardless of what node we are running on. The representation also
%% permits easy identification of the pid's node.
pid_to_string(Pid) when is_pid(Pid) ->
    %% see http://erlang.org/doc/apps/erts/erl_ext_dist.html (8.10 and
    %% 8.7)
    <<131,103,100,NodeLen:16,NodeBin:NodeLen/binary,Id:32,Ser:32,_Cre:8>>
        = term_to_binary(Pid),
    Node = binary_to_term(<<131,100,NodeLen:16,NodeBin:NodeLen/binary>>),
    lists:flatten(io_lib:format("<~w.~B.~B>", [Node, Id, Ser])).

%% inverse of above
string_to_pid(Str) ->
    Err = {error, {invalid_pid_syntax, Str}},
    %% The \ before the trailing $ is only there to keep emacs
    %% font-lock from getting confused.
    case re:run(Str, "^<(.*)\\.([0-9]+)\\.([0-9]+)>\$",
                [{capture,all_but_first,list}]) of
        {match, [NodeStr, IdStr, SerStr]} ->
            %% the NodeStr atom might be quoted, so we have to parse
            %% it rather than doing a simple list_to_atom
            NodeAtom = case erl_scan:string(NodeStr) of
                           {ok, [{atom, _, X}], _} -> X;
                           {error, _, _} -> throw(Err)
                       end,
            <<131,NodeEnc/binary>> = term_to_binary(NodeAtom),
            Id = list_to_integer(IdStr),
            Ser = list_to_integer(SerStr),
            binary_to_term(<<131,103,NodeEnc/binary,Id:32,Ser:32,0:8>>);
        nomatch ->
            throw(Err)
    end.

version_compare(A, B, lte) ->
    case version_compare(A, B) of
        eq -> true;
        lt -> true;
        gt -> false
    end;
version_compare(A, B, gte) ->
    case version_compare(A, B) of
        eq -> true;
        gt -> true;
        lt -> false
    end;
version_compare(A, B, Result) ->
    Result =:= version_compare(A, B).

version_compare(A, A) ->
    eq;
version_compare([], [$0 | B]) ->
    version_compare([], dropdot(B));
version_compare([], _) ->
    lt; %% 2.3 < 2.3.1
version_compare([$0 | A], []) ->
    version_compare(dropdot(A), []);
version_compare(_, []) ->
    gt; %% 2.3.1 > 2.3
version_compare(A,  B) ->
    {AStr, ATl} = lists:splitwith(fun (X) -> X =/= $. end, A),
    {BStr, BTl} = lists:splitwith(fun (X) -> X =/= $. end, B),
    ANum = list_to_integer(AStr),
    BNum = list_to_integer(BStr),
    if ANum =:= BNum -> version_compare(dropdot(ATl), dropdot(BTl));
       ANum < BNum   -> lt;
       ANum > BNum   -> gt
    end.

dropdot(A) -> lists:dropwhile(fun (X) -> X =:= $. end, A).

recursive_delete(Files) ->
    lists:foldl(fun (Path,  ok                   ) -> recursive_delete1(Path);
                    (_Path, {error, _Err} = Error) -> Error
                end, ok, Files).

recursive_delete1(Path) ->
    case filelib:is_dir(Path) of
        false -> case file:delete(Path) of
                     ok              -> ok;
                     {error, enoent} -> ok; %% Path doesn't exist anyway
                     {error, Err}    -> {error, {Path, Err}}
                 end;
        true  -> case file:list_dir(Path) of
                     {ok, FileNames} ->
                         case lists:foldl(
                                fun (FileName, ok) ->
                                        recursive_delete1(
                                          filename:join(Path, FileName));
                                    (_FileName, Error) ->
                                        Error
                                end, ok, FileNames) of
                             ok ->
                                 case file:del_dir(Path) of
                                     ok           -> ok;
                                     {error, Err} -> {error, {Path, Err}}
                                 end;
                             {error, _Err} = Error ->
                                 Error
                         end;
                     {error, Err} ->
                         {error, {Path, Err}}
                 end
    end.

dict_cons(Key, Value, Dict) ->
    dict:update(Key, fun (List) -> [Value | List] end, [Value], Dict).

orddict_cons(Key, Value, Dict) ->
    orddict:update(Key, fun (List) -> [Value | List] end, [Value], Dict).

unlink_and_capture_exit(Pid) ->
    unlink(Pid),
    receive {'EXIT', Pid, _} -> ok
    after 0 -> ok
    end.

% Separate flags and options from arguments.
% get_options([{flag, "-q"}, {option, "-p", "/"}],
%             ["set_permissions","-p","/","guest",
%              "-q",".*",".*",".*"])
% == {["set_permissions","guest",".*",".*",".*"],
%     [{"-q",true},{"-p","/"}]}
get_options(Defs, As) ->
    lists:foldl(fun(Def, {AsIn, RsIn}) ->
                        {AsOut, Value} = case Def of
                                             {flag, Key} ->
                                                 get_flag(Key, AsIn);
                                             {option, Key, Default} ->
                                                 get_option(Key, Default, AsIn)
                                         end,
                        {AsOut, [{Key, Value} | RsIn]}
                end, {As, []}, Defs).

get_option(K, _Default, [K, V | As]) ->
    {As, V};
get_option(K, Default, [Nk | As]) ->
    {As1, V} = get_option(K, Default, As),
    {[Nk | As1], V};
get_option(_, Default, As) ->
    {As, Default}.

get_flag(K, [K | As]) ->
    {As, true};
get_flag(K, [Nk | As]) ->
    {As1, V} = get_flag(K, As),
    {[Nk | As1], V};
get_flag(_, []) ->
    {[], false}.
