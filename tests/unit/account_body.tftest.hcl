mock_provider "azapi" {}
mock_provider "azurerm" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}

variables {
  kind      = "AIServices"
  location  = "swedencentral"
  name      = "aif-unit-test"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit-test"
  sku_name  = "S0"
}

run "ai_service_is_the_account_address" {
  command = plan

  assert {
    condition     = length(azapi_resource.ai_service) == 1 && length(azapi_resource.this) == 0
    error_message = "kind = AIServices must create exactly azapi_resource.ai_service[0] and no azapi_resource.this."
  }
}

run "associated_projects_default_omitted" {
  command = plan

  assert {
    condition     = !contains(keys(azapi_resource.ai_service[0].body.properties), "associatedProjects")
    error_message = "associatedProjects must be omitted from the body when associated_projects is null (default)."
  }

  assert {
    condition     = !contains(keys(azapi_resource.ai_service[0].body.properties), "defaultProject")
    error_message = "defaultProject must be omitted from the body when default_project is null (default)."
  }
}

run "associated_projects_explicit_list" {
  command = plan

  variables {
    associated_projects = ["content-factory", "aca-stack-ci"]
    default_project     = "content-factory"
  }

  assert {
    condition     = jsonencode(azapi_resource.ai_service[0].body.properties.associatedProjects) == jsonencode(["content-factory", "aca-stack-ci"])
    error_message = "associatedProjects must contain exactly the supplied list."
  }

  assert {
    condition     = azapi_resource.ai_service[0].body.properties.defaultProject == "content-factory"
    error_message = "defaultProject must be sent when default_project is set."
  }
}

run "associated_projects_explicit_empty_list" {
  command = plan

  variables {
    associated_projects = []
  }

  assert {
    condition     = jsonencode(azapi_resource.ai_service[0].body.properties.associatedProjects) == "[]"
    error_message = "An explicit empty associated_projects list must be sent as an empty associatedProjects array."
  }
}

run "resource_api_version_default" {
  command = plan

  variables {
    is_hsm_key = true
  }

  assert {
    condition     = azapi_resource.ai_service[0].type == "Microsoft.CognitiveServices/accounts@2025-06-01"
    error_message = "The account type must default to Microsoft.CognitiveServices/accounts@2025-06-01."
  }

  assert {
    condition     = azapi_update_resource.ai_service_hsm_key[0].type == "Microsoft.CognitiveServices/accounts@2025-06-01"
    error_message = "The HSM encryption update must use the account API version (default 2025-06-01)."
  }
}

run "resource_api_version_override" {
  command = plan

  variables {
    is_hsm_key           = true
    resource_api_version = "2026-05-01"
  }

  assert {
    condition     = azapi_resource.ai_service[0].type == "Microsoft.CognitiveServices/accounts@2026-05-01"
    error_message = "The account type must follow resource_api_version."
  }

  assert {
    condition     = azapi_update_resource.ai_service_hsm_key[0].type == "Microsoft.CognitiveServices/accounts@2026-05-01"
    error_message = "The HSM encryption update must follow resource_api_version."
  }
}

run "resource_api_version_preview_accepted" {
  command = plan

  variables {
    resource_api_version = "2025-10-01-preview"
  }

  assert {
    condition     = azapi_resource.ai_service[0].type == "Microsoft.CognitiveServices/accounts@2025-10-01-preview"
    error_message = "A -preview API version must be accepted and applied to the account type."
  }
}

run "resource_api_version_override_non_ai_services_kind" {
  command = plan

  variables {
    kind                 = "OpenAI"
    resource_api_version = "2026-05-01"
  }

  assert {
    condition     = azapi_resource.this[0].type == "Microsoft.CognitiveServices/accounts@2026-05-01"
    error_message = "The non-AIServices account (azapi_resource.this) type must follow resource_api_version."
  }
}

run "resource_api_version_rejects_bad_format" {
  command = plan

  variables {
    resource_api_version = "2026-5-1"
  }

  expect_failures = [
    var.resource_api_version,
  ]
}

run "resource_api_version_rejects_unknown_suffix" {
  command = plan

  variables {
    resource_api_version = "2026-05-01-beta"
  }

  expect_failures = [
    var.resource_api_version,
  ]
}

run "optional_properties_omitted_when_null" {
  command = plan

  assert {
    condition     = !contains(keys(azapi_resource.ai_service[0].body.properties), "amlWorkspace")
    error_message = "amlWorkspace must be omitted from the body when aml_workspace is null."
  }

  assert {
    condition     = !contains(keys(azapi_resource.ai_service[0].body.properties), "networkInjections")
    error_message = "networkInjections must be omitted from the body when network_injections is null."
  }

  assert {
    condition     = !contains(keys(azapi_resource.ai_service[0].body.properties), "raiMonitorConfig")
    error_message = "raiMonitorConfig must be omitted from the body when rai_monitor_config is null."
  }
}

run "optional_properties_sent_when_set" {
  command = plan

  variables {
    aml_workspace = {
      resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit-test/providers/Microsoft.MachineLearningServices/workspaces/mlw-unit-test"
    }
    network_injections = {
      subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit-test/providers/Microsoft.Network/virtualNetworks/vnet-unit-test/subnets/agents"
      scenario  = "agent"
    }
    rai_monitor_config = {
      adx_storage_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit-test/providers/Microsoft.Storage/storageAccounts/stunittest"
    }
  }

  assert {
    condition     = azapi_resource.ai_service[0].body.properties.amlWorkspace.resourceId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit-test/providers/Microsoft.MachineLearningServices/workspaces/mlw-unit-test"
    error_message = "amlWorkspace.resourceId must be sent when aml_workspace is set."
  }

  assert {
    condition     = azapi_resource.ai_service[0].body.properties.networkInjections[0].scenario == "agent"
    error_message = "networkInjections must be sent when network_injections is set."
  }

  assert {
    condition     = azapi_resource.ai_service[0].body.properties.raiMonitorConfig.adxStorageResourceId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit-test/providers/Microsoft.Storage/storageAccounts/stunittest"
    error_message = "raiMonitorConfig must be sent when rai_monitor_config is set."
  }
}
