// TODO : Refactor this to leverage the WebSite/main.bicep module vs this creating the resources. 
// - Be a facade to the WebSite module
// - Set additional appSettings. 
// - Create the storage account.

// Parameters
@description('Required. ')
param name string

@description('Required. The kind of FunctionAPp.')
@allowed([
  'workflow'
  'function'
])
param type string = 'function'

@description('Required. The Function App service plan id.')
param planId string

@description('Required. The Azure Storage Account bound to the Function App. Used to generate the appSettings.')
param storageAccountName string

@description('Optional. The AppInsights Instrumentation Key.')
param appInsightsInstrumentationKey string = ''

// Parameters with defaults
@description('Optional. Tags to apply to the resources.')
param tags object = {}

@description('Optional. Datacenter location of the Function App.')
param location string = resourceGroup().location

@description('Optional. Enable diagnostic logs. Defaults to false.')
param enableDiagnostics bool = false

@description('Optional. Resource ID for the Log Analytics Workspace where logs will be sent.')
param workspaceId string = ''

@description('Optional. Enable application logging such as HTTP and FailedRequests. Defaults to false.')
param enableLogging bool = false

@description('Optional. Configures the functionExtensionVersion setting. Defaults to ~4.')
param functionExtensionVersion string = '~4'

@description('Optional. Configures the functionRuntime setting. Defaults todotnet.')
@allowed([
  'dotnet'
  'node'
])
param functionRuntime string = 'dotnet'

@description('Optional. Additional set of configuration to add to the FunctionApp.')
param appSettings array = []

@description('Optional. Enable pre-live / staging slot.')
param enableStagingSlot bool = false

// Variables
var resourceName = name
var kind = ((type == 'function') ? 'functionapp' : 'functionapp,workflowapp')
// Resources
resource sa 'Microsoft.Storage/storageAccounts@2021-08-01' existing = {
  name: storageAccountName
}

var baseSettings = [
  {
    name: 'AzureWebJobsStorage'
    value: 'DefaultEndpointsProtocol=https;AccountName=${sa.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(sa.id, sa.apiVersion).keys[0].value}'
  }
  {
    name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
    value: 'DefaultEndpointsProtocol=https;AccountName=${sa.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(sa.id, sa.apiVersion).keys[0].value}'
  }
  {
    name: 'FUNCTIONS_WORKER_RUNTIME'
    value: functionRuntime
  }
  {
    name: 'FUNCTIONS_EXTENSION_VERSION'
    value: functionExtensionVersion
  }
  {
    name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
    value: appInsightsInstrumentationKey
  }
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: 'InstrumentationKey=${appInsightsInstrumentationKey}'
  }
]
var identity = {
  type: 'SystemAssigned'
}
var funcAppSetting = [
  {
    name: 'WEBSITE_RUN_FROM_PACKAGE'
    value: '1'
  }
]
var settings = concat(baseSettings, appSettings, ((kind == 'functionapp') ? funcAppSetting : []))
var siteProps = {
  serverFarmId: planId
  siteConfig: {
    appSettings: settings
  }
  httpsOnly: true
}
var funcLogs = [ {
    category: 'FunctionAppLogs'
    enabled: true
  } ]
var workflowLogs = [ {
    category: 'WorkflowRuntime'
    enabled: true
  } ]
var logs = concat(funcLogs, ((kind == 'workflow') ? workflowLogs : []))
resource functionApp 'Microsoft.Web/sites@2020-12-01' = {
  name: resourceName
  location: location
  kind: kind
  tags: tags
  identity: identity
  properties: siteProps
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  scope: functionApp
  name: 'diagnosticSettings'
  properties: {
    workspaceId: workspaceId
    logs: logs
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource appServiceLogging 'Microsoft.Web/sites/config@2020-06-01' = if (enableLogging) {
  name: '${functionApp.name}/logs'
  properties: {
    applicationLogs: {
      fileSystem: {
        level: 'Warning'
      }
    }
    httpLogs: {
      fileSystem: {
        retentionInMb: 40
        enabled: true
      }
    }
    failedRequestsTracing: {
      enabled: true
    }
    detailedErrorMessages: {
      enabled: true
    }
  }
}

resource stagingSlot 'Microsoft.Web/sites/slots@2021-03-01' = if (enableStagingSlot) {
  name: 'staging'
  location: location
  kind: 'functionapp'
  parent: functionApp
  tags: tags
  identity: identity
  properties: siteProps
}

// Output
output Id string = functionApp.id
output Identity string = functionApp.identity.principalId
output Name string = functionApp.name
