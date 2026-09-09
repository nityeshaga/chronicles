# frozen_string_literal: true

# The file-bundle half of the explorable tools: turning the `files` argument into
# { path:, content: } pairs the model can write, and describing a bundle back.
module ExplorableToolSupport
  FILE_ARGUMENT = 'Each file is {"path": "decks/10-drive.html", "content": "..."} — path relative to the bundle root (forward slashes, no leading slash, no ..), content the file\'s text. For a binary file (an image, a font) add "encoding": "base64" and base64-encode the content.'

  private
    # Returns [files, error]. Paths are normalised so "./a.html" and "a.html" are one file;
    # base64 is decoded here so the model only ever sees bytes.
    def unpack_files(files)
      unpacked = files.map do |file|
        file = file.to_h.symbolize_keys
        path = Explorable::Asset.normalize_path(file[:path])
        return [ nil, { error: "Every file needs a path and a content string. Offending entry: #{file.inspect.truncate(120)}" } ] if path.blank? || file[:content].nil?

        content = file[:content].to_s
        if file[:encoding].to_s == "base64"
          content = Base64.strict_decode64(content.delete("\n"))
        end
        { path: path, content: content }
      rescue ArgumentError
        return [ nil, { error: "#{file[:path]} says encoding base64 but its content isn't valid base64." } ]
      end

      duplicates = unpacked.map { |file| file[:path] }.tally.select { |_, n| n > 1 }.keys
      return [ nil, { error: "The same path appears more than once: #{duplicates.join(", ")}." } ] if duplicates.any?

      [ unpacked, nil ]
    end

    def describe(explorable, warnings: [])
      {
        id: explorable.id,
        slug: explorable.slug,
        status: status_of(explorable),
        url: public_url(explorable),
        edit_url: edit_url(explorable),
        files: [ Explorable::INDEX, *explorable.assets.where.not(path: Explorable::INDEX).order(:path).pluck(:path) ],
        missing_references: explorable.missing_references.presence,
        warnings: warnings.presence
      }.compact
    end

    # An unresolvable relative link is the one mistake a bundle can make that nothing
    # else will catch: the page renders, the deck 404s, and only a reader finds out.
    def missing_reference_warning(explorable)
      missing = explorable.missing_references
      return if missing.none?

      "#{missing.size} relative #{"reference".pluralize(missing.size)} won't resolve — not in the bundle: #{missing.first(5).join(", ")}#{" (+#{missing.size - 5} more)" if missing.size > 5}. Add the files with update_explorable, or fix the links."
    end
end
