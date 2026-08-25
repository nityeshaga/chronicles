# The one renderer for an image in a body. An editor upload (active_storage/blobs/_blob),
# a remote image (action_text/attachables/_remote_image) and the importer's 250 Ghost
# images all come out as the same figure — Ghost's kg-image-card, the one shape the
# public CSS styles — so a reader can't tell how an image got into a post.
#
# Twin notice: the editor canvas is the one place this can't reach. Lexxy paints an image
# with its own node renderer, and app/javascript/lexxy_kg_cards.js turns this exact figure
# back into that node when a post opens. Change the shape here and change it there.
module ImageCardsHelper
  def kg_image_card(src:, alt: nil, caption: nil, width: nil, height: nil, srcset: nil, sizes: nil)
    tag.figure class: class_names("kg-card kg-image-card", "kg-card-hascaption": caption.present?) do
      concat tag.img(src:, srcset:, sizes:, class: "kg-image", alt: alt.to_s, width:, height:, loading: "lazy")
      concat tag.figcaption(sanitize(caption)) if caption.present?
    end
  end

  # Candidates for the browser to choose from by viewport: two variants under the original,
  # and the original itself once Active Storage has measured it.
  def kg_image_srcset(blob)
    width = blob.metadata["width"]
    candidates = [ 720, 1440 ].select { |w| width.nil? || w < width }.map do |w|
      "#{url_for(blob.representation(resize_to_limit: [ w, nil ]))} #{w}w"
    end
    candidates << "#{url_for(blob)} #{width}w" if width
    candidates.join(", ")
  end
end
