request = {
  container-1 = {    // Copy and paste as much as needed
    type     = "udp"                                # 'tcp', 'udp', 'file', or 'http'
    app_name = "forti-test"
    sub_name = "forti-test"
    format   = "none"                           # Change to json if needed
    // log_file_pat = "/path/to/log/file.log"   # Apply to type type file,
    // port_to_listen    = 5140                 # Doesn't Apply to file
    // sender_ip_address = 5140                 # The IP address of the sending machine or system
  }
}
coralogix_domain      = "Europe"                      # Can be either - Europe, Europe2, India, Singapore or US
coralogix_private_key = ""
additional_tags       = {}
subnet_id             = "subnet-0164d0f7cf5a5a427"
ssh_key               = "ireland"