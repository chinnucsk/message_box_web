-module(message_box_web_sup).

-behaviour(supervisor).

%% External exports
-export([start_link/0, upgrade/0]).

%% supervisor callbacks
-export([init/1]).

%% @spec start_link() -> ServerRet
%% @doc API for starting the supervisor.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% @spec upgrade() -> ok
%% @doc Add processes if necessary.
upgrade() ->
    {ok, {_, Specs}} = init([]),

    Old = sets:from_list(
            [Name || {Name, _, _, _} <- supervisor:which_children(?MODULE)]),
    New = sets:from_list([Name || {Name, _, _, _, _, _} <- Specs]),
    Kill = sets:subtract(Old, New),

    sets:fold(fun (Id, ok) ->
                      supervisor:terminate_child(?MODULE, Id),
                      supervisor:delete_child(?MODULE, Id),
                      ok
              end, ok, Kill),

    [supervisor:start_child(?MODULE, Spec) || Spec <- Specs],
    ok.

%% @spec init([]) -> SupervisorTree
%% @doc supervisor callback.
init([]) ->
    Ip = case os:getenv("MOCHIWEB_IP") of false -> "0.0.0.0"; Any -> Any end,   
    WebConfig = [
		 {ip, Ip},
                 {port, 8000}
                ],

    %% Sets up the BeepBeep environment. Removing any of the below
    %% will cause something to break.
    BaseDir = message_box_web_deps:get_base_dir(),

    Web = {message_box_web_web,
	   {message_box_web_web, start, [WebConfig]},
	   permanent, 5000, worker, dynamic},
    Router = {beepbeep_router,
	      {beepbeep_router, start, [BaseDir]},
	      permanent, 5000, worker, dynamic},
    SessionServer = {beepbeep_session_server,
		     {beepbeep_session_server,start,[]},
		     permanent, 5000, worker, dynamic},
    
    Processes = [Router,SessionServer,Web],
    {ok, {{one_for_one, 10, 10}, Processes}}.
