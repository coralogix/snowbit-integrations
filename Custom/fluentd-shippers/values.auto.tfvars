request = {
  container-1 = {    // Copy and paste as much as needed
    type     = ""                                # 'tcp', 'udp', 'file', or 'http'
    app_name = ""
    sub_name = ""
    format   = "none"                           # Change to json if needed
    // log_file_pat = "/path/to/log/file.log"   # When using type file,
  }
}
coralogix_domain      = ""                      # Can be either - Europe, Europe2, India, Singapore or US
coralogix_private_key = ""
additional_tags       = {}
subnet_id             = ""
ssh_key               = ""