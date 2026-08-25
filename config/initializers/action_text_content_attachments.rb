# A content attachment carries its markup in a `content` attribute, and the renderer
# sanitizes that attribute on every page view (ActionText::Content#render_attachments).
# The editor reads the rendered form back and writes it as the attribute again, so a body
# stored with unsanitized markup — a tweet's <script>, Ghost's data-* hooks, the view
# annotations development adds — changed shape on its next save with nothing typed.
# Running the renderer's own pass on the way in makes the first save store what every
# later render and save will produce: the stored body is a fixed point, not a moving one.
ActiveSupport.on_load(:action_text_rich_text) do
  before_save do
    self.body = body.fragment.replace("#{ActionText::Attachment.tag_name}[content]") do |node|
      node["content"] = body.sanitize_content_attachment(node["content"])
      node
    end
  end
end
