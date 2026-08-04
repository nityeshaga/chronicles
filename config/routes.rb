Rails.application.routes.draw do
  # Ghost quietly served the whole site on www too — duplicate content. Here www
  # exists only to 301 to the apex, path and query preserved. The canonical host is
  # read from Setting at request time — a boot-time host constraint can't, because
  # the row needn't exist when routes are drawn (schema load precedes seed).
  constraints(->(req) { req.host == "www.#{Setting.current.production_host}" }) do
    get "(*path)", to: redirect(status: 301) { |_params, req| "https://#{Setting.current.production_host}#{req.original_fullpath}" }
  end

  root "posts#index"

  get "rss", to: "posts#index", defaults: { format: "rss" }, as: :rss

  # Ghost served a sitemap index pointing at four children; match the shape so old
  # Search Console submissions keep resolving.
  get "sitemap.xml",         to: "sitemaps#index",   as: :sitemap
  get "sitemap-posts.xml",   to: "sitemaps#posts",   as: :sitemap_posts
  get "sitemap-pages.xml",   to: "sitemaps#pages",   as: :sitemap_pages
  get "sitemap-tags.xml",    to: "sitemaps#tags",    as: :sitemap_tags
  get "sitemap-authors.xml", to: "sitemaps#authors", as: :sitemap_authors

  get "tag/:slug", to: "tags#show", as: :tag

  # Email signups from the homepage's subscribe section. Public + unauthenticated, so
  # it must sit above the catch-all root-slug route at the bottom.
  resources :subscribers, only: :create

  resource :session, only: %i[ new create destroy ]

  # OAuth — lets claude.ai connect to /mcp from a pasted URL. We manage apps via
  # dynamic client registration, not the Doorkeeper admin UI, so skip it.
  use_doorkeeper do
    skip_controllers :applications
  end

  # Discovery (RFC 8414 / RFC 9728). The *path variants let a client derive the
  # well-known URL from a resource identifier and still resolve.
  get "/.well-known/oauth-authorization-server",       to: "oauth_metadata#show"
  get "/.well-known/oauth-authorization-server/*path",  to: "oauth_metadata#show"
  get "/.well-known/oauth-protected-resource",          to: "oauth_metadata#protected_resource"
  get "/.well-known/oauth-protected-resource/*path",    to: "oauth_metadata#protected_resource"

  # Dynamic Client Registration (RFC 7591).
  post "/oauth/register", to: "oauth/registrations#create"

  namespace :writing do
    root "posts#index"
    resources :posts do
      resource :publishing, only: %i[ create destroy ]
    end
    # Pages have no index of their own — they're listed on the writing index alongside
    # posts — so drop that route rather than leave it pointing at a missing action.
    resources :pages, except: %i[ index ] do
      resource :publishing, only: %i[ create destroy ]
    end
    # HTML pages are edited through their own controller — a monospace textarea over the
    # stored document, never the Lexxy form — but they publish through the same nested
    # resource as everything else. Listed on the writing index, so no index of their own.
    resources :html_pages, except: %i[ index ] do
      resource :publishing, only: %i[ create destroy ]
    end
    resources :tags, only: %i[ index edit update create ]
    resources :embeds, only: %i[ create ]
    resources :uploads, only: %i[ create ]
    resource :connect, only: %i[ show ]
    resources :api_tokens, only: %i[ create destroy ]
    resources :connected_apps, only: %i[ destroy ]
    resources :subscribers, only: %i[ index ]
  end

  # Ghost's author archive had ~zero traffic; keep old inbound links resolving.
  get "author/nityesh", to: redirect("/about/", status: 301)

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Retired Ghost URLs Google still knows about. Paginated archives and AMP pages
  # no longer exist here; 301 them to their living equivalents so that link equity
  # and crawl budget aren't spent on 404s. :page is digits-only so a real slug like
  # /page/ never gets shadowed. Targets carry the trailing slash (Ghost parity).
  get "page/:page", to: redirect("/", status: 301), constraints: { page: /\d+/ }
  get "tag/:slug/page/:page", to: redirect("/tag/%{slug}/", status: 301), constraints: { page: /\d+/ }
  get ":slug/amp", to: redirect("/%{slug}/", status: 301)

  # Public post pages live at the root — same slugs Ghost served. Keep this LAST so it
  # doesn't shadow the named routes above.
  resources :posts, param: :slug, path: "", only: %i[ show ]
end
