# Who is holding the pen. Evaluated inside the engine's controller, so anything a
# controller can see works here: Current.user, current_user (Devise), a session lookup.
# Nil means nobody is signed in, and the pen answers 403.
Redpen.author = -> { Current.user }

# May this author pen this path? Called with the page path and the author. Default: any
# signed-in author, on any path. Narrow it to whoever owns the page:
#
#   Redpen.annotatable = ->(path, author) { Community.at(path)&.administered_by?(author) }

# The engine's controllers inherit from this, so your authentication runs first.
# Redpen.parent_controller = "ApplicationController"
