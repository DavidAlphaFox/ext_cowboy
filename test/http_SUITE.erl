%% Copyright (c) 2013, Egobrain <xazar.studio@gmail.com>
%%
%% Permission to use, copy, modify, and/or distribute this software for any
%% purpose with or without fee is hereby granted, provided that the above
%% copyright notice and this permission notice appear in all copies.
%%
%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
%% WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
%% MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
%% ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
%% WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
%% ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
%% OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

-module(http_SUITE).

-include_lib("common_test/include/ct.hrl").

%% ct.
-export([
         all/0,
         groups/0,
         init_per_suite/1,
         end_per_suite/1,
         init_per_group/2,
         end_per_group/2
        ]).

%% Tests.
-export([
         multipart_file/1,
         multipart_files/1,
         multipart_big_file_error/1,
         multipart_files_error/1,

         multipart_prop/1,
         multipart_props/1,
         multipart_big_prop_error/1,
         multipart_props_error/1
        ]).

all() ->
    [
     {group, http}
    ].

groups() ->
    Tests = [
             multipart_file,
             multipart_files,
             multipart_big_file_error,
             multipart_files_error,

             multipart_prop,
             multipart_props,
             multipart_big_prop_error,
             multipart_props_error
            ],
    [
     {http, [parallel], Tests}
    ].

init_per_suite(Config) ->
    application:start(crypto),
    application:start(cowlib),
    application:start(ranch),
    application:start(cowboy),
    Config.

end_per_suite(_Config) ->
    application:stop(cowboy),
    application:stop(ranch),
    application:stop(cowlib),
    application:stop(crypto),
    ok.

init_per_group(http, Config) ->
    Transport = ranch_tcp,
    {ok, _} = cowboy:start_http(http, 100, [{port, 0}],
                                [
                                 {env, [{dispatch, init_dispatch(Config)}]},
                                 {max_keepalive, 50},
                                 {timeout, 500}
                                ]),
    Port = ranch:get_port(http),
    {ok, Client} = cowboy_client:init([]),
    [{scheme, <<"http">>}, {port, Port}, {opts, []},
     {transport, Transport}, {client, Client}|Config].

end_per_group(Name, _) ->
    cowboy:stop_listener(Name),
    ok.

%% Dispatch configuration.

init_dispatch(_Config) ->
    cowboy_router:compile(
      [
       {"localhost",
        [
         {"/uploader", http_uploader, []}
        ]}
      ]).

%% Convenience functions.

build_url(Path, Config) ->
    {scheme, Scheme} = lists:keyfind(scheme, 1, Config),
    {port, Port} = lists:keyfind(port, 1, Config),
    PortBin = list_to_binary(integer_to_list(Port)),
    PathBin = list_to_binary(Path),
    << Scheme/binary, "://localhost:", PortBin/binary, PathBin/binary >>.

%% Tests.

multipart_file(Config) ->
    Body = gen_binary(1000),
    Parts = [
             {[{<<"content-disposition">>,
                <<"form-data; name=\"f1\"; filename=\"file1.raw\"">>},
               {<<"content-type">>, <<"application/octet-stream">>}],
              Body}
            ],
    Url = "/uploader?max_file_size=1000&max_files=1",
    {ok, Res} = multipart_test(Config, Url, Parts),
    [
     {files,
      [
       {<<"f1">>, [
                   {path, Path},
                   {size, 1000},
                   {filename, <<"file1.raw">>},
                   {content_type, <<"application/octet-stream">>}
                  ]}
      ]},
     {props,[]}
    ] = Res,
    {ok, Body} = file:read_file(Path).

multipart_files(Config) ->
    Body1 = gen_binary(1000),
    Body2 = gen_binary(2000),
    Parts = [
             {[{<<"content-disposition">>,
                <<"form-data; name=\"fm1\"; filename=\"file-m1.raw\"">>},
               {<<"content-type">>, <<"application/octet-stream">>}],
              Body1},
             {[{<<"content-disposition">>,
                <<"form-data; name=\"fm2\"; filename=\"file-m2.raw\"">>},
               {<<"content-type">>, <<"application/octet-stream">>}],
              Body2}
            ],
    Url = "/uploader?max_file_size=2000&max_files=2",
    {ok, Res} = multipart_test(Config, Url, Parts),
    [
     {files,
      [
       {<<"fm1">>, [
                    {path, Path1},
                    {size, 1000},
                    {filename, <<"file-m1.raw">>},
                    {content_type, <<"application/octet-stream">>}
                   ]},
       {<<"fm2">>, [
                    {path, Path2},
                    {size, 2000},
                    {filename, <<"file-m2.raw">>},
                    {content_type, <<"application/octet-stream">>}
                   ]}
      ]},
     {props,[]}
    ] = Res,
    {ok, Body1} = file:read_file(Path1),
    {ok, Body2} = file:read_file(Path2).

multipart_big_file_error(Config) ->
    Parts = [
             {[{<<"content-disposition">>,
                <<"form-data; name=\"fe1\"; filename=\"file-e1.raw\"">>},
               {<<"content-type">>, <<"application/octet-stream">>}],
              gen_binary(1000)}
            ],
    Url = "/uploader?max_file_size=999&max_files=1",
    {error, {<<"fe1">>, {max_size, 999}}} = multipart_test(Config, Url, Parts).

multipart_files_error(Config) ->
    Parts = [
             {[{<<"content-disposition">>,
                <<"form-data; name=\"fme1\"; filename=\"file-me1.raw\"">>},
               {<<"content-type">>, <<"application/octet-stream">>}],
              gen_binary(1000)},
             {[{<<"content-disposition">>,
                <<"form-data; name=\"fme2\"; filename=\"file-me2.raw\"">>},
               {<<"content-type">>, <<"application/octet-stream">>}],
              gen_binary(1000)}
            ],
    Url = "/uploader?max_file_size=1000&max_files=1",
    {error, {max_files, 1}} = multipart_test(Config, Url, Parts).

multipart_prop(Config) ->
    Parts = [
             {[{<<"content-disposition">>, <<"form-data; name=\"p1\"">>}],
              <<"property_1">>}
            ],
    Url = "/uploader?max_prop_size=5000&max_props=1",
    {ok, Res} = multipart_test(Config, Url, Parts),
    [
     {files,[]},
     {props,[
             {<<"p1">>, <<"property_1">>}
            ]}
    ] = Res.

multipart_props(Config) ->
    Parts = [
             {[{<<"content-disposition">>, <<"form-data; name=\"pm1\"">>}],
              <<"property_1">>},
             {[{<<"content-disposition">>, <<"form-data; name=\"pm2\"">>}],
              <<"property_2">>}
            ],
    Url = "/uploader?max_prop_size=5000&max_props=2",
    {ok, Res} = multipart_test(Config, Url, Parts),
    [
     {files,[]},
     {props,[
             {<<"pm1">>, <<"property_1">>},
             {<<"pm2">>, <<"property_2">>}
            ]}
    ] = Res.

multipart_big_prop_error(Config) ->
    Parts = [
             {[{<<"content-disposition">>, <<"form-data; name=\"pe1\"">>}],
              <<"012345678910">>}
            ],
    Url = "/uploader?max_prop_size=10&max_props=1",
    {error, Reason} = multipart_test(Config, Url, Parts),
    {<<"pe1">>, {max_size, 10}} = Reason.

multipart_props_error(Config) ->
    Parts = [
             {[{<<"content-disposition">>, <<"form-data; name=\"pme1\"">>}],
              <<"property_1">>},
             {[{<<"content-disposition">>, <<"form-data; name=\"pme2\"">>}],
              <<"property_2">>}
            ],
    Url = "/uploader?max_prop_size=5000&max_props=1",
    {error, Reason} = multipart_test(Config, Url, Parts),
    {max_props, 1} = Reason.

multipart_test(Config, Url, Parts) ->
    Client = ?config(client, Config),
    Boundry = <<"--OHai">>,
    Body = join_parts(Parts, Boundry),
    %% ct:pal("Body:~n~s~n", [Body]),
    {ok, Client2} = cowboy_client:request(
                      <<"POST">>,
                      build_url(Url, Config),
                      [{<<"content-type">>,
                        <<"multipart/form-data; boundary=",
                          Boundry/binary>>}
                      ],
                      Body, Client),
    {ok, 200, _, Client3} = cowboy_client:response(Client2),
    {ok, RespBody, _} = cowboy_client:response_body(Client3),
    binary_to_term(RespBody).

gen_binary(Bytes) ->
    crypto:strong_rand_bytes(Bytes).

join_parts(Parts, Boundry) ->
    binary:list_to_bin(
      [
       [
        <<"\r\n--", Boundry/binary>>,
        << <<"\r\n", H/binary, ": ", V/binary>> || {H, V} <- Headers>>,
        <<"\r\n\r\n", Body/binary>>
       ] || {Headers, Body} <- Parts
      ] ++ [<<"\r\n--", Boundry/binary, "--\r\n">>]).
