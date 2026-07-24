# Enqueue every job only after its enclosing transaction commits, so a job can
# never fire for a row that rolled back (the ghost row).
ActiveSupport.on_load(:active_job) do
  self.enqueue_after_transaction_commit = true
end
