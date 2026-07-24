# nityesh.com

Nityesh's personal blog — a vanilla Rails 8 app that replaced a Ghost blog. The migration was **parity-gated**: every URL Ghost served (posts, tags, sitemaps, RSS) renders the same here, so old links, SEO, and Search Console submissions kept working. That history explains most of this codebase's quirks; they're documented below so nobody "fixes" them by accident.

**Stack:** Rails 8.1 · Hotwire (Turbo + Stimulus) · [Lexxy](https://github.com/basecamp/lexxy) rich-text editor on Action Text · importmap + propshaft (no build step, no Tailwind — deliberate) · SQLite + Solid Queue/Cache/Cable · Kamal to a DigitalOcean droplet.

## Writing (the part Nityesh actually uses)

- Everything lives under **`/writing`** (sign-in required). Dashboard tabs: Drafts / Scheduled / Published / Pages.
- The editor autosaves drafts every 2s, silently. The slug field commits on blur only. New tags are minted with their own explicit button — not by autosave.
- **Publish** (top right) publishes now, or schedules if you pick a future time. Scheduling enqueues a Solid Queue job; unpublishing or re-publishing cancels the old schedule safely.
- Pages (like About) and tag names/slugs/descriptions are edited under `/writing` too. **Changing a tag slug breaks its public URL** — the UI warns you.
- The subtitle line under the title is the post's `excerpt`: it renders as the standfirst on the post, on the home feed, and in social cards.
- One author, one login. Forgot the password? `bin/rails runner 'User.first.update!(password: "newpass")'` on the server (or locally, `bin/rails db:seed` prints a fresh one for a new DB).

## Running locally

Ruby comes from [mise](https://mise.jdx.dev) (`.ruby-version` → 3.4.7). Prefix commands with `mise exec --` if ruby isn't on your PATH.

```bash
bundle install
bin/rails db:prepare     # creates + migrates SQLite
bin/rails db:seed        # creates the one author, prints a password ONCE
bin/rails server         # http://localhost:3000 — /writing to sign in
```

Tests and lint (both must be green before pushing):

```bash
bin/rails test           # unit + integration
bin/rails test:system    # rack_test driver — see "Testing" below
bin/rubocop              # bare, no args — the config excludes views on purpose
```

## Deploying

Pushing/merging to `main` auto-deploys: the `deploy` job in `.github/workflows/ci.yml` runs `bin/kamal deploy` after tests pass. Manual: `bin/kamal deploy` from a machine with the deploy key.

The origin server IP is kept out of git (the site is Cloudflare-fronted). `config/deploy.yml` is ERB-evaluated and reads it from `KAMAL_SERVER_IP` — export it before a manual `bin/kamal deploy`; CI injects it from the `KAMAL_SERVER_IP` repo secret. See the comment block at the top of `config/deploy.yml` for the full list of deploy env vars.

- Target: a single droplet behind Cloudflare; kamal-proxy owns 80/443 and routes by Host header.
- Live URL: `https://nityesh.com` — the sslip.io fallback host (built from `KAMAL_SERVER_IP`) exists only for Let's Encrypt cert provisioning; cutting over = edit `proxy.hosts` in `config/deploy.yml` + point DNS.
- Migrated Ghost images are served from a volume at `/content/images/...` — they are **not** in the repo or in Active Storage.
- Health check: `/up` (excluded from the force_ssl redirect; don't remove that exclusion).
- `script/parity_check.rb` compares a set of reference URLs between two hosts — useful after risky changes: `PARITY_BASE=http://localhost:3000 ruby script/parity_check.rb`.

## Map

| Where | What |
|---|---|
| `app/models/post.rb` | The heart: slugs, publish/schedule/unpublish, `Page < Post` (STI) |
| `app/models/page.rb` | Pages override only the seams (`og_type`, `body_class`, …) |
| `lib/ghost/` | One-time Ghost import (mobiledoc → Action Text HTML). Keep: it documents the stored-content shape |
| `app/controllers/writing/` | The authoring UI (posts, pages, tags, publishings, embeds) |
| `app/views/shared/_meta.html.erb` | All SEO/OG/Twitter head tags, shaped for Ghost parity |
| `app/javascript/controllers/` | Stimulus: autosave, autogrow, slug, embed, editor, dashboard… |
| `app/assets/stylesheets/application.css` | The whole design, hand-written. Public typography + editor canvas share selector lists |

## Conventions and landmines (read before changing anything)

**Doctrine.** Vanilla Rails, the 37signals way: server-rendered ERB, Hotwire, hand-written CSS, no JS framework, no build step, underdo. If a change needs a package.json, it's probably the wrong change.

**Ghost parity is load-bearing.**
- Public URLs end in a trailing slash (Ghost's shape). Never hand-type `trailing_slash: true` — use the `public_post_path`/`public_tag_path` helpers. Admin paths stay bare; `ApplicationController` redirects public requests to the slashed form.
- Migrated post bodies in the production DB contain Ghost's `kg-*` card markup (`kg-image-card`, `kg-gallery-card`, …) — the importer wrote it there on purpose. The `kg-*` CSS rules must stay or old posts' images/galleries/embeds break. The `gh-*` class *names* are legacy and may be renamed someday, but the styles they carry ARE the site's design.
- Sitemap URLs, RSS shape, and the `/author/nityesh` redirect all match what Ghost served. Don't tidy them.

**STI.** `Page < Post`, discriminated by `type`. Use the `Post.articles` scope for posts-only queries — never hand-type `where(type: "Post")`. `posts#show` and `Writing::PostsController#set_post` are unfiltered **on purpose** (pages are served/edited through them; the comments at those sites say so).

**Publishing.** `published_at` on a draft with a future time = a schedule. The enqueued job carries its scheduled time and publishes only if `published_at` still equals it — that identity check is what stops a stale job from republishing a post that was since unpublished. Two traps: timestamps are **floored to whole seconds** (SQLite keeps µs, the job serializer keeps ns — sub-second stamps break the equality; tests must floor too), and if you ever change `PublishJob#perform`'s signature, jobs already sitting in the production queue will error when they fire — check for scheduled posts before deploying such a change.

**Autosave contract.** The debounced autosave PATCHes with an `X-Autosave` header and expects silence: `204` on success, **bodyless** `422` on validation failure (never `render :edit` — it would repaint the page mid-keystroke). Explicit saves are normal Turbo submits. Slug is excluded from the debounce (commits on blur); the tag-mint input is form-associated elsewhere and must not trigger autosave.

**Editor (Lexxy).** Its content styles are `:where(.lexxy-content)`-scoped at zero specificity — *designed* to be overridden by the app. WYSIWYG parity works by factoring the published `.gh-content` typography into selector lists **shared** with `.editor-canvas__body`: change one, you change both, which is the point. Theme the chrome via `--lexxy-*` CSS variables. Never fight the gem with `!important`. Note the site's `html{font-size:62.5%}`: naked `rem` values from third-party CSS compute smaller than you expect.

**Caching.** Public pages use fragment caches keyed on posts plus `fresh_when` ETags. Anything rendered inside `cache post` that lives on another record needs a touch path — e.g. `Tag` touches its posts on rename. If you add such data, add the touch.

**Testing.** The system-test driver is `rack_test` — **no JavaScript executes** (documented in `application_system_test_case.rb`). JS behavior is covered by unit/integration tests + manual dogfood; don't add a browser driver casually, and don't trust a green system test to prove a Stimulus controller works. CI runs on Linux: its clock has ns precision where macOS has µs — another reason time-sensitive tests use floored stamps.

**Style.** Comments are sparse and explain *why*, never what. Rationale goes in commit messages. Match this or the reviewers (human and otherwise) will send it back.

## For agents

Everything above applies to you, plus: run `bin/rails test && bin/rubocop` before declaring anything done; keep diffs surgical; PRs need a review-pack body (what/why/verification) and are **never self-merged** — a human merges. The founder measures the writing experience against Ghost's editor and the codebase against 37signals' taste. When in doubt, underdo.
