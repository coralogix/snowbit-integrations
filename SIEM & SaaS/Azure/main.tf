terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.19.0"
    }
  }
}
provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "this" {
  name = "test-rg"
}

resource "azurerm_eventhub_authorization_rule" "this" {
  eventhub_name       = "internal-eh"
  name                = "authorization_rule-1"
  namespace_name      = "coralogix-test"
  send                = true
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_key_vault" "this" {
  name                = "test-2"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  sku_name            = "standard"
  tenant_id           = "" # add Azure-AD tenant ID
}

#resource "azurerm_monitor_diagnostic_setting" "example" {
#  depends_on = [azurerm_eventhub_authorization_rule.this]
#  name                           = "example-1"
#  target_resource_id             = azurerm_key_vault.this.id
#  eventhub_authorization_rule_id = azurerm_eventhub_authorization_rule.this.id
#  log {
#    category = "AuditLogs"
#  }
#}