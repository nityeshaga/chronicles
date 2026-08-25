# touch_attachment_records is off (config/application.rb) so that analysing an uploaded
# image doesn't move the post's lock_version. In Rails 8.1.3.1 the off branch of
# ActiveStorage::Blob#touch_attachments iterates the association as loaded, and while a
# blob is being attached that target holds the very attachment being created — the
# attachment's `belongs_to :blob, autosave: true` saves the just-identified blob first,
# the blob's after_update runs, and touching the new record raises. Upstream fixed it by
# guarding (`attachment.touch unless attachment.new_record?`, rails/rails#55156, on
# 8-1-stable but not in 8.1.3.1); querying for persisted attachments here has the same
# effect. Delete this file once the installed blob.rb carries the new_record? guard —
# check on every Rails upgrade: `grep new_record? $(bundle show activestorage)/app/models/active_storage/blob.rb`.
Rails.application.config.to_prepare do
  ActiveStorage::Blob.prepend(Module.new do
    private
      def touch_attachments
        ActiveStorage::Attachment.where(blob_id: id).each(&:touch)
      end
  end)
end
