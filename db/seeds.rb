# Idempotent seed: the one author who can sign in and write. Ghost had exactly one
# user; so do we. A brand-new random password is generated and printed once — there
# is no settings screen to change it, so grab it from the console output (or reset it
# in `rails console`).
email = "nityeshagarwal@gmail.com"

if (user = User.find_by(email_address: email))
  puts "User #{email} already exists (id=#{user.id}); leaving password untouched."
else
  password = SecureRandom.base58(16)
  User.create!(name: "Nityesh Agarwal", email_address: email, password: password)
  puts "Created author #{email}"
  puts "Generated password: #{password}"
  puts "Save it now — it is not stored anywhere else and won't be printed again."
end

# The single site-identity row. The CreateSettings migration backfills this on an
# existing database; this covers a brand-new DB built via `db:schema:load` (where
# the data migration never runs). Idempotent so re-seeding is safe.
if Setting.exists?
  puts "Site setting already present; leaving it untouched."
else
  Setting.create!(
    site_title:        "Chronicles of Nityesh",
    site_description:  "Hot takes, secret recipes, leaked memos and epic fails - from a creator building a SaaS business",
    site_logo:         "/content/images/2024/12/nityesh-com-logo-bg-removed.png",
    author_name:       "Nityesh Agarwal",
    author_image:      "/content/images/size/w160/2024/12/nityesh-headshot-2.jpeg",
    author_image_full: "/content/images/2024/12/nityesh-headshot-2.jpeg",
    author_image_size: 465,
    author_path:       "author/nityesh/",
    twitter_handle:    "@nityeshaga",
    home_meta_title:   "Nityesh Agarwal - founder of Curated Connections",
    production_host:   "nityesh.com"
  )
  puts "Created site setting."
end
