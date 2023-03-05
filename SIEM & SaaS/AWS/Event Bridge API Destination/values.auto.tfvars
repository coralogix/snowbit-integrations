coralogix_endpoint   = ""   # Can be either 'Europe', 'Europe2', 'India', 'Singapore' or 'US'
event_pattern        = [ # List (even with one value) that can be either 'auth0', 'inspector_findings' or 'guardDuty_findings'
  "auth0",
  ""
]
auth0_event_bus_name = ""
application_name     = ""   # Logical Name for Coralogix account
subsystem_name       = ""   # Logical Name for Coralogix account
private_key          = ""   # The 'Send your data' API key from Coralogix account
additional_tags      = {
  # Optional - adds AWS tags to all resources
  #  example_key = "example value"
}
