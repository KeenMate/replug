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

  @impl true
  def init(opts) do
    plug = parse_plug_opt(opts)
    opts_opt = parse_opts_opt(opts)

    %{
      plug: plug,
      opts: opts_opt
    }
  end

  @impl true
  def call(conn, %{plug: {plug_type, plug_module, plug_opts}, opts: opts}) do
    opts = build_plug_opts(plug_type, plug_module, plug_opts, opts)

    call_plug(conn, plug_type, plug_module, opts)
  end

  defp call_plug(conn, :fn, {plug_module, plug_function}, opts) do
    apply(plug_module, plug_function, [conn, opts])
  end

  defp call_plug(conn, :mod, plug_module, opts) do
    plug_module.call(conn, opts)
  end

  defp parse_plug_opt(opts) do
    case Keyword.get(opts, :plug) do
      nil ->
        raise("Replug requires a :plug entry with a module or tuple value")

      {{plug_module, plug_function} = plug, opts} when is_atom(plug_module) and is_atom(plug_function) ->
        {:fn, plug, opts}

      {plug, opts} when is_atom(plug) ->
        {:mod, plug, opts}

      plug when is_atom(plug) ->
        {:mod, plug, :only_dynamic_opts}
    end
    # |> plug_with_type()
  end

  defp parse_opts_opt(opts) do
    case Keyword.get(opts, :opts) do
      nil ->
        raise("Replug requires a :opts entry")

      {opts_module, opts_function} ->
        {opts_module, opts_function, []}

      {opts_module, opts_function, opts_args} ->
        {opts_module, opts_function, opts_args}
    end
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
    Code.ensure_loaded!(plug_module)
    if function_exported?(plug_module, :init, 1) do
      plug_module.init(opts)
    else
      opts
    end
  end

  defp call_opts({opts_module, opts_function, opt_args}) do
    apply(opts_module, opts_function, opt_args)
  end

  defp merge_opts(static_opts, dynamic_opts)
       when is_list(static_opts) and is_list(dynamic_opts) do
    Keyword.merge(static_opts, dynamic_opts)
  end

  defp merge_opts(static_opts, dynamic_opts) when is_map(static_opts) and is_map(dynamic_opts) do
    Map.merge(static_opts, dynamic_opts)
  end
end
