-module(frontend).
-export([start/0]).

-include("ccs.hrl").


%Função para criar um mapa: PidState -> [Empresa], para sabermos qual o ator de state que gere as operacoes daquela empresa

mapaStateEmpresa(Map, []) ->
    Map
;

mapaStateEmpresa(Map, [H | T]) ->
  SocketBin = maps:get(<<"socket">>, H),
  PortaPush = list_to_integer(binary_to_list(maps:get(<<"Push">>, SocketBin))),
  PortaPull = list_to_integer(binary_to_list(maps:get(<<"Pull">>, SocketBin))),
  io:format("Push : ~p , Pull: ~p ~n",[PortaPush, PortaPull]),
  ListaEmpresasBin = maps:get(<<"empresas">>, H),
  ListaEmpresas = [binary_to_list(E) || E <- ListaEmpresasBin],
  io:format("~p~n", [ListaEmpresas]),
  {Push, Pull} = criaSocket(PortaPush, PortaPull),
  PidStateA = frontend_state:start(Push, Pull, ListaEmpresas),
  Map2 = maps:put(PidStateA, ListaEmpresas, Map),
  mapaStateEmpresa(Map2, T)
.

criaSocket(PortaPush, PortaPull) ->

    %%%  Ligacao via zeromq à exchange

    {ok, Push} = chumak:socket(push),

    %12351
    case chumak:connect(Push, tcp, "localhost", PortaPush) of
        {ok, _} ->
            io:format("Binding OK with Pid: ~p\n", [Push]);
        {error, Reason} ->
            io:format("Connection Failed for this reason: ~p\n", [Reason]);
        X ->
            io:format("Unhandled reply for bind ~p \n", [X])
        end,
    
    {ok, Pull} = chumak:socket(pull),

    %12350
    case chumak:connect(Pull, tcp, "localhost", PortaPull) of
        {ok, _BindPid} ->
            io:format("Binding OK with Pid: ~p\n", [Pull]);
        {error, Reason1} ->
            io:format("Connection Failed for this reason: ~p\n", [Reason1]);
        X1 ->
            io:format("Unhandled reply for bind ~p \n", [X1])
        end,

    {Push, Pull}.

 %% Fim da ligacao


start() ->
    
  
  % Modificar a passar o que obtemos do JSON
  io:format("cheguei, falta chumack~n"),
  application:start(chumak),

  
%% Inicializacao do frontendState, com os sockets de push e pull

  io:format("Servidor de Frontend Principal ja esta a correr!~n"),

  {ok, Ficheiro} = file:read_file("modelo.json"),
  Json = jiffy:decode(Ficheiro, [return_maps]),
  io:fwrite("~p~n", [Json]),

  login_manager:start( maps:get(<<"Utilizadores">>, Json) ),

  MapState = mapaStateEmpresa(#{}, maps:get(<<"Exchanges">>, Json)),
  io:format("~p~n", [MapState]),



   {ok, LSock} = gen_tcp:listen(12345, [binary, {packet, 4}, {active, true}, {reuseaddr, true}]),

   acceptor(LSock, MapState)
.

acceptor(LSock, MapState) ->
  {ok, Sock} = gen_tcp:accept(LSock),
  Pid = spawn(fun() -> autenticaCliente(Sock, MapState) end),
  gen_tcp:controlling_process(Sock, Pid),
  acceptor(LSock, MapState).


  
autenticaCliente(Sock, MapState) ->
   io:format("Vou receber~n"),
   receive
      {tcp, _, Autenticacao} -> 

              io:format("cheguei~n",[]),
              {'Autenticacao', User, Pass} = ccs:decode_msg(Autenticacao,'Autenticacao'),
              io:format("User: "),
              io:format(User),
              io:format("!\nPass: "),
              io:format(Pass),
              io:format("!\n"),

              
              Res = login_manager:login(User,Pass),
              case Res of  
                invalid -> Bin = ccs:encode_msg(#'RespostaAutenticacao'{sucesso = false}),
                    gen_tcp:send(Sock, Bin),
                    autenticaCliente(Sock, MapState);

                {Resposta, E, L , List} ->
                io:format(Resposta),
                io:format("\n"),
                case Resposta of
                    "licitador" -> 
                        io:format("Vou pedir papel~n"),
                        Papel = Resposta,
                        io:format("Já recebi papel do State e papel : ~p~n",[Papel]),
                        Bin = ccs:encode_msg(#'RespostaAutenticacao'{sucesso = true, papel = Papel, leilaoSubscrito = L, emissaoSubscrita = E, empresasSubscritas = List }),
                        gen_tcp:send(Sock, Bin),
                        %%Agora vou iniciar o ator que vai tratar do cliente
                        %Pid = spawn(frontend_client, start, [Sock, User, Papel, MapState]),
                        %gen_tcp:controlling_process(Sock, Pid),
%                        io:format("O PID do processo criado é: ~p~n", [Pid]),
                        frontend_client:start(Sock, User, Papel, MapState);

                    "empresa" -> 
                        io:format("Vou pedir papel~n"),
                        Papel = Resposta,
                        io:format("Já recebi papel do State e papel : ~p~n",[Papel]),
                        Bin = ccs:encode_msg(#'RespostaAutenticacao'{sucesso = true, papel = Papel, leilaoSubscrito = L, emissaoSubscrita = E, empresasSubscritas = List }),
                        gen_tcp:send(Sock, Bin),
                        io:format("~p~n",[Sock]),
                        io:format("~p~n",[User]),
                        io:format("~p~n",[Papel]),
                        io:format("~p~n",[MapState]),
                        %%Agora vou iniciar o ator que vai tratar da empresa
                        frontend_client:start(Sock, User, Papel, MapState)
                        %io:format("O PID do processo criado é: ~p~n", [Pid])
                    end
                end
                ;
      {tcp_closed,_} ->
            io:format("utilizador nao se autenticou nem registou e saiu~n",[]),
            true
    end
.
