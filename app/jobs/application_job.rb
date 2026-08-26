class ApplicationJob < ActiveJob::Base
  include ActiveJobRowLevelSecurity

  retry_on ActiveRecord::Deadlocked
  discard_on ActiveJob::DeserializationError
  queue_as :low_priority # default queue
end
