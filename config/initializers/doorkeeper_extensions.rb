# frozen_string_literal: true

# Extend Doorkeeper to support CIMD (Client ID Metadata Documents) and to fix
# localhost redirect URI matching for native clients like Claude Code.
Rails.application.config.to_prepare do
  # Resolve URL-based client_ids by fetching their metadata document. This slots
  # into Doorkeeper's flows transparently: by_uid_and_secret calls by_uid, and
  # public clients (secret.blank? && !confidential?) are already handled.
  Doorkeeper::Application.class_eval do
    def self.by_uid(uid)
      if uid.to_s.match?(%r{\Ahttps?://})
        CimdResolver.new(uid).resolve
      else
        find_by(uid: uid.to_s)
      end
    end
  end

  # Doorkeeper's loopback_uri? leans on IPAddr, which doesn't count "localhost"
  # as loopback (only 127.0.0.1/::1). Native OAuth clients use ephemeral ports on
  # localhost, and per RFC 8252 §7.3 the port is ignored for loopback URIs.
  Doorkeeper::OAuth::Helpers::URIChecker.singleton_class.prepend(Module.new do
    def loopback_uri?(uri)
      return true if uri.host == "localhost"

      super
    end
  end)
end
