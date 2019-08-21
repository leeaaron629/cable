defmodule Http do
    
    require Logger

    def start_link(port: port, dispatch: dispatch) do
        
        {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :http_bin, active: false])
        Logger.info("Accepting connections on port #{port}")

        {:ok, spawn_link(Http, :accept, [socket, dispatch])}

    end

    def accept(socket, dispatch) do
        
        {:ok, request} = :gen_tcp.accept(socket)
        
        IO.puts "Received request: #{inspect request}"

        spawn(fn -> dispatch.(request) end)

        accept(socket, dispatch)

    end

    def read_request(request, acc \\ %{headers: []}) do

        result = :gen_tcp.recv(request, 0)
        |> IO.inspect

        case result do
            {:ok, {:http_request, :GET, {:abs_path, full_path}, _}} ->
                read_request(request, Map.put(acc, :full_path, full_path))
            {:ok, :http_eoh} ->
                acc
            {:ok, {:http_header, _, key, _, value}} ->
                read_request(
                    request,
                    Map.put(acc, :headers, [{String.downcase(to_string(key)), value} | acc.headers])
                )
            {:ok, _line} -> 
                read_request(request, acc)
        end
    end

    def send_response(socket, response) do
        :gen_tcp.send(socket, response)
        :gen_tcp.close(socket)
    end
    
    def child_spec(opts) do

        port = opts[:port]
        dispatch = opts[:dispatch]
        IO.puts "Starting Http with ports: #{inspect port} dispatch: #{inspect dispatch}"

        %{id: Http, start: {Http, :start_link, [opts]}}
    end

end