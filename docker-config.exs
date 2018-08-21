use Mix.Config

###
# Tooling for runtime-configuration
###
defmodule Docker do
    ###
    # Gets an environment variable and casts it accordingly.
    ###
    def env(shortname, verbatim \\ false) do
        name = if verbatim, do: "", else: "pleroma_" <> Atom.to_string(shortname) |> String.upcase()
        raw_var = System.get_env(name)

        if raw_var == nil do
            raise "Could not find #{name} in environment. Please define it and try again."
        end

        if !String.contains?(raw_var, ":") do
            raw_var
        else
            var_parts = String.split(raw_var, ":", parts: 2)

            type = Enum.at(var_parts, 0)
            var = Enum.at(var_parts, 1)

            noop = fn(x) -> x end

            # Auto-select function and return call
            (case type do
                "int" -> fn(x) -> Integer.parse(x) |> elem(0) end
                "bool" -> fn(x) -> x == "true" end
                "string" -> noop
                _ -> if verbatim, do: noop, else: raise "Unknown type #{type} used in variable #{raw_var}."
            end).(var)
        end
    end

    ###
    # Gets an environment variable and splits it
    ###
    def split(shortname, verbatim \\ false) do
        var = Docker.env(shortname, verbatim)

        if var == nil do
            []
        else
            var
            |> String.split(';')
            |> Enum.map(&String.trim/1)
        end
    end
end

###
# Apply config
###
config :logger, level: String.to_atom(Docker.env(:loglevel) || "info")

config :pleroma, :emoji, shortcode_globs: Docker.split(:emoji_shortcode_globs)

config :pleroma, Pleroma.Web.Endpoint,
    url: [
        host: Docker.env(:url),
        scheme: Docker.env(:scheme),
        port: Docker.env(:port)
    ],
    secret_key_base: Docker.env(:secret_key_base)

config :pleroma, Pleroma.Upload,
    uploads: Docker.env(:uploads_path),
    strip_exif: Docker.env(:uploads_strip_exif)

config :pleroma, :chat,
    enabled: Docker.env(:chat_enabled)

config :pleroma, :instance,
    name: Docker.env(:name),
    description: Docker.env(:description),
    email: Docker.env(:admin_email),
    limit: Docker.env(:max_notice_chars),
    registrations_open: Docker.env(:registrations_open),
    federating: Docker.env(:federating),
    rewrite_policy: Docker.split(:rewrite_policies)

if Docker.split(:rewrite_policies) |> Enum.any?(fn(x) -> x == "Pleroma.Web.ActivityPub.MRF.SimplePolicy" end) do
    config :pleroma, :mrf_simple,
        media_removal: Docker.split(:mrf_media_removal),
        media_nsfw: Docker.split(:mrf_media_nsfw),
        reject: Docker.split(:mrf_reject),
        federated_timeline_removal: Docker.split(:mrf_federated_timeline_removal)
end

config :pleroma, :media_proxy,
    enabled: Docker.env(:media_proxy_enabled),
    redirect_on_failure: Docker.env(:media_proxy_redirect_on_failure),
    base_url: Docker.env(:media_proxy_url)

config :pleroma, Pleroma.Repo,
    adapter: Ecto.Adapters.Postgres,
    username: Docker.env(:postgres_user, true),
    password: Docker.env(:postgres_password, true),
    database: Docker.env(:postgres_db, true),
    hostname: Docker.env(:postgres_ip, true),
    pool_size: Docker.env(:db_pool_size)

config :pleroma, :fe,
  theme: Docker.env(:fe_theme),
  logo: Docker.env(:fe_logo),
  background: Docker.env(:fe_background),
  redirect_root_no_login: Docker.env(:fe_redirect_no_login),
  redirect_root_login: Docker.env(:fe_redirect_login),
  show_instance_panel: Docker.env(:fe_show_instance_panel),
  show_who_to_follow_panel: Docker.env(:fe_show_who_to_follow_panel),
  who_to_follow_provider: Docker.env(:fe_who_to_follow_provider),
  who_to_follow_link: Docker.env(:fe_who_to_follow_link),
  scope_options_enabled: Docker.env(:fe_scope_options_enabled)
