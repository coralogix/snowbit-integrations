# Coralogix OTEL Linux secure & cron parser
# Requires: coralogix/coralogix provider, CORALOGIX_API_KEY or api_key in provider

terraform {
  required_providers {
    coralogix = {
      source  = "coralogix/coralogix"
      version = "~> 1.0"
    }
  }
}

provider "coralogix" {
  api_key = var.coralogix_api_key
  domain  = var.coralogix_endpoint
}

resource "coralogix_parsing_rules" "otel_linux_secure_cron" {
  name        = "OTEL Linux secure & cron (auth.log, cron)"
  description = "EXTRACT only - keeps original log intact, adds new JSON keys: body, source, timestamp, hostname, tag, pid, message, user, src_ip, action, eventtype, dest, cron_cmd, host, dvc, process, app"
  enabled     = true

  rule_subgroups {
    order   = 1
    enabled = true

    rules {
      extract {
        name               = "Extract body from OTEL JSON"
        source_field       = "text"
        regular_expression = "\"body\"\\s*:\\s*\"(?P<body>[^\"]*)\""
      }
    }
    rules {
      extract {
        name               = "Extract source (log.file.name)"
        source_field       = "text"
        regular_expression = "\"log\\.file\\.name\"\\s*:\\s*\"(?P<source>[^\"]*)\""
      }
    }
  }

  rule_subgroups {
    order   = 2
    enabled = true

    rules {
      extract {
        name               = "Extract syslog from text"
        source_field       = "text"
        regular_expression = "^(?P<timestamp>[A-Za-z]{3}\\s+\\d{1,2}\\s+\\d{2}:\\d{2}:\\d{2})\\s+(?P<hostname>\\S+)\\s+(?P<tag>\\S+?)(\\[(?P<pid>\\d+)\\])?:\\s*(?P<message>.*)$"
      }
    }
    rules {
      extract {
        name               = "Extract syslog from body"
        source_field       = "text.body"
        regular_expression = "^(?P<timestamp>[A-Za-z]{3}\\s+\\d{1,2}\\s+\\d{2}:\\d{2}:\\d{2})\\s+(?P<hostname>\\S+)\\s+(?P<tag>\\S+?)(\\[(?P<pid>\\d+)\\])?:\\s*(?P<message>.*)$"
      }
    }
  }

  rule_subgroups {
    order   = 3
    enabled = true

    rules {
      extract {
        name               = "Extract user from session"
        source_field       = "text.message"
        regular_expression = "session (?:opened|closed) for user (?P<user>\\S+)(?:\\(uid=\\d+\\))?|Accepted (?:password|publickey) for (?P<user>\\S+) from"
      }
    }
    rules {
      extract {
        name               = "Extract src_ip"
        source_field       = "text.message"
        regular_expression = "(?:from|Received disconnect from)\\s+(?P<src_ip>\\d+\\.\\d+\\.\\d+\\.\\d+)"
      }
    }
    rules {
      extract {
        name               = "Extract action"
        source_field       = "text.message"
        regular_expression = "(?P<action>opened|closed|disconnected|Accepted|Failed)"
      }
    }
    rules {
      extract {
        name               = "Extract eventtype"
        source_field       = "text.message"
        regular_expression = "(?P<eventtype>pam_unix|sshd|runuser|sudo|su|login|polkit)(?:\\([^)]+\\))?:"
      }
    }
    rules {
      extract {
        name               = "Extract dest from disconnect"
        source_field       = "text.message"
        regular_expression = "disconnect from (?P<dest>\\d+\\.\\d+\\.\\d+\\.\\d+)"
      }
    }
    rules {
      extract {
        name               = "Extract cron user"
        source_field       = "text.message"
        regular_expression = "\\((?P<user>\\w+)\\)\\s+CMD"
      }
    }
    rules {
      extract {
        name               = "Extract cron_cmd"
        source_field       = "text.message"
        regular_expression = "CMD\\s+\\((?P<cron_cmd>[^)]+)\\)"
      }
    }
  }

  rule_subgroups {
    order   = 4
    enabled = true

    rules {
      extract {
        name               = "Extract host from hostname"
        source_field       = "text.hostname"
        regular_expression = "^(?P<host>.+)$"
      }
    }
    rules {
      extract {
        name               = "Extract dvc from hostname"
        source_field       = "text.hostname"
        regular_expression = "^(?P<dvc>.+)$"
      }
    }
    rules {
      extract {
        name               = "Extract process from tag"
        source_field       = "text.tag"
        regular_expression = "^(?P<process>.+)$"
      }
    }
    rules {
      extract {
        name               = "Extract app from tag"
        source_field       = "text.tag"
        regular_expression = "^(?P<app>.+)$"
      }
    }
    rules {
      extract {
        name               = "Extract src from src_ip"
        source_field       = "text.src_ip"
        regular_expression = "^(?P<src>.+)$"
      }
    }
    rules {
      extract {
        name               = "Extract user_name from user"
        source_field       = "text.user"
        regular_expression = "^(?P<user_name>.+)$"
      }
    }
  }
}
