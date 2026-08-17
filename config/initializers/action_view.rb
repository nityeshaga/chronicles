# Namespaced controllers prefix object partial paths with their namespace, so a
# Writing:: preview rendering an Action Text body went looking for
# writing/action_text/contents/_content and 500'd every post carrying an embed
# (Action Text renders a content attachment's inner Content as an object). Nothing
# here wants the prefix: /writing has no object partials of its own, and its previews
# render the public posts/_post on purpose, so the whole site can share one set.
ActiveSupport.on_load(:action_view) do
  self.prefix_partial_path_with_controller_namespace = false
end
