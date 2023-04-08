request = {
  container-1 = {              // copy and paste as much as needed
    type     = ""              # 'tcp', 'udp' or 'http'
    app_name = ""
    sub_name = ""
    format   = "none"          # change to json if needed
  },
  container-2 = {
    type     = ""
    app_name = ""
    sub_name = ""
    format   = "none"
  }
}
coralogix_domain      = ""     # Can be either - Europe, Europe2, India, Singapore or US
coralogix_private_key = ""
additional_tags       = {}
subnet_id             = ""