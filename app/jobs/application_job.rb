class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # A deleted post before its scheduled publish fires → drop the job, don't crash.
  discard_on ActiveJob::DeserializationError
end
