defmodule Replug do
  @moduledoc """
  ```
  # ---- router.ex ----
  plug Replug,
    plug: Corsica,
    opts: {MyAppWeb.PlugConfigs, :corsica}

  # ---- plug_configs.ex ----
  defmodule MyAppWeb.PlugConfigs do
    def corsica do
      [
        max_age: System.get_env("CORSICA_MAX_AGE"),
        expose_headers: ~w(X-Foo),
        origins: System.get_env("VALID_ORIGINS")
      ]
    end
  end
  ```
  """

  @behaviour Plug

  defguardp is_valid_plug_name(plug) when is_atom(plug) or is_function(plug)

  @impl true
  def init(opts) do
    plug = parse_plug_opt(opts)

    %{
      plug: plug,
      opts: Keyword.get(opts, :opts) || raise("Replug requires a :opts entry")
    }
  end

  @impl true
  def call(conn, %{plug: {plug_type, plug_module, plug_opts}, opts: opts}) do
    opts = build_plug_opts(plug_type, plug_module, plug_opts, opts)

    call_plug(conn, plug_type, plug_module, opts)
  end

  defp call_plug(conn, :fn, plug_fn, opts) do
    plug_fn.(conn, opts)
  end

  defp call_plug(conn, :mod, plug_module, opts) do
    plug_module.call(conn, opts)
  end

  defp parse_plug_opt(opts) do
    case Keyword.get(opts, :plug) do
      nil ->
        raise("Replug requires a :plug entry with a module or tuple value")

      {plug, opts} when is_valid_plug_name(plug) ->
        {plug, opts}

      plug when is_valid_plug_name(plug) ->
        {plug, :only_dynamic_opts}
    end
    |> plug_with_type()
  end

  defp plug_with_type({plug_param, opts}) when is_function(plug_param) do
    {:fn, plug_param, opts}
  end

  defp plug_with_type({plug_param, opts}) when is_atom(plug_param) do
    {:mod, plug_param, opts}
  end

  defp build_plug_opts(plug_type, plug, plug_opts, opts) do
    dynamic_opts = call_opts(opts)

    case plug_opts do
      :only_dynamic_opts ->
        dynamic_opts

      static_opts ->
        merge_opts(static_opts, dynamic_opts)
    end
    |> maybe_plug_init(plug_type, plug)
  end

  defp maybe_plug_init(opts, :fn, _plug_fn) do
    opts
  end

  defp maybe_plug_init(opts, :mod, plug_module) do
    plug_module.init(opts)
  end

  defp call_opts({opts_module, opts_function, opt_args}) do
    apply(opts_module, opts_function, opt_args)
  end

  defp call_opts(opts_fn) when is_function(opts_fn) do
    opts_fn.()
  end

  defp merge_opts(static_opts, dynamic_opts)
       when is_list(static_opts) and is_list(dynamic_opts) do
    Keyword.merge(static_opts, dynamic_opts)
  end

  defp merge_opts(static_opts, dynamic_opts) when is_map(static_opts) and is_map(dynamic_opts) do
    Map.merge(static_opts, dynamic_opts)
  end
end
