# Who is asking. A real host has authentication here; the demo has none, so the
# tenant comes from the request and defaults to the first customer.
class Current < ActiveSupport::CurrentAttributes
  attribute :tenant
end
