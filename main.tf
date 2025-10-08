# All toghether in main.tf for simplicity
# In production, consider splitting into multiple .tf files for better organization

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    hashicorpnull = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  subscription_id = "558e107b-72db-476d-8b02-e509ff720372"
  #resource_provider_registrations = "none"
  features {}
}

# ====================================================================================================
# VARIABLES (Equivalent to your YAML variables)
# ====================================================================================================

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US 2" # East US could create the azurerm_service_plan 
}

variable "function_app_name" {
  description = "Function App name"
  type        = string
  default     = ""
}

variable "storage_account_name" {
  description = "Storage Account name"
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "Resource Group name"
  type        = string
  default     = ""
}

variable "app_service_plan_name" {
  description = "App Service Plan name"
  type        = string
  default     = ""
}

# ====================================================================================================
# LOCAL VALUES (Computed naming like your YAML variables)
# ====================================================================================================

locals {
  resource_group_name    = var.resource_group_name != "" ? var.resource_group_name : "ps-fn-app-demo-rg"
  app_service_plan_name  = var.app_service_plan_name != "" ? var.app_service_plan_name : "stproject-appserviceplan-${var.environment}"
  storage_account_name   = var.storage_account_name != "" ? var.storage_account_name : "stprojstoracc${var.environment}"
  function_app_name      = var.function_app_name != "" ? var.function_app_name : "ps-fn-app-demo"
}

# ====================================================================================================
# DATA SOURCES
# ====================================================================================================

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
}

# ====================================================================================================
# APP SERVICE PLAN (Consumption Plan for Functions)
# ====================================================================================================

resource "azurerm_service_plan" "function_plan" {
  name                = local.app_service_plan_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"  # Change to "Windows" if needed
  sku_name            = "Y1"     # Consumption plan
  
  tags = {
    Environment = var.environment
    Purpose     = "FunctionApp"
  }
}

# ====================================================================================================
# STORAGE ACCOUNT (Equivalent to your az storage account create command)
# ====================================================================================================

resource "azurerm_storage_account" "function_storage" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "RAGRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"
  is_hns_enabled           = true  
  
  # Security settings (equivalent to --allow-blob-public-access false)
  allow_nested_items_to_be_public = true # false
}

# ====================================================================================================
# FUNCTION APP: stores multiple functions 
# ====================================================================================================

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_function_app
resource "azurerm_linux_function_app" "function_app" {
  name                = local.function_app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.function_plan.id
  
  storage_account_name = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key
  public_network_access_enabled = true
  
  app_settings = {
    "FUNCTIONS_EXTENSION_VERSION"               = "~4"
    "FUNCTIONS_WORKER_RUNTIME"                   = "powershell"
    "AzureWebJobsStorage"                      = azurerm_storage_account.function_storage.primary_connection_string
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = azurerm_storage_account.function_storage.primary_connection_string
    "WEBSITE_CONTENTSHARE"                     = local.function_app_name
    "STORAGE_CONNECTION_STRING"                = azurerm_storage_account.function_storage.primary_connection_string
  }  
  
  site_config {
    application_stack {
      powershell_core_version = "7.4"  # Adjust based on your runtime --> az functionapp list-runtimes
    }
    # CORS settings if needed
    cors {
      allowed_origins = ["*"]  # Restrict as needed ex. --> allowed_origins     = ["https://portal.azure.com"]
      # support_credentials = true  # ERROR SupportCredentials can not be true when allowedOrigins includes '*'
    }
  }
}

data "azurerm_function_app_host_keys" "host_keys" {
  name                = azurerm_linux_function_app.function_app.name
  resource_group_name = azurerm_linux_function_app.function_app.resource_group_name

  depends_on = [azurerm_linux_function_app.function_app]
}

# ====================================================================================================
# FUNCTION CODE DEPLOYMENT (Equivalent to AzureFunctionApp@1 task)
# ====================================================================================================

resource "azurerm_function_app_function" "http_trigger_ps_fn" {
  name            = "http-trigger-ps-fn"
  function_app_id = azurerm_linux_function_app.function_app.id
  language        = "PowerShell"
  
  file {
    name    = "run.ps1"
    content = file("${path.module}/run.ps1")
  }

  test_data = jsonencode({
    "name" = "Azure"
  })
  
  config_json = jsonencode({
    "bindings" = [
      {
        "scriptFile" : "run.ps1",
        "authLevel" = "function",
        "type" = "httpTrigger",
        "direction" = "in",
        "name" = "Request",
        "methods" = [ "get", "post" ]
      },
      {
        "type"      = "http",
        "direction" = "out",
        "name"      = "Response"
      }
    ]
  })
}

# ====================================================================================================
# OUTPUTS
# ====================================================================================================

output "resource_group_name" {
  description = "Resource Group name"
  value       = azurerm_resource_group.main.name
}

output "storage_account_name" {
  description = "Storage Account name"
  value       = azurerm_storage_account.function_storage.name
}

output "function_app_url" {
  description = "Function App URL"
  value       = "https://${azurerm_linux_function_app.function_app.default_hostname}"
}

output "http_trigger_ps_fn_url" {
  description = "Function App test URL"
  value       = "invocation_url: ${azurerm_function_app_function.http_trigger_ps_fn.invocation_url}?code=${nonsensitive(data.azurerm_function_app_host_keys.host_keys.default_function_key)}"
}




