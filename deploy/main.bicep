@description('Required. Affix used when naming Azure resources.')
param purpose string

@description('Required. Specifies the logical environment for all resources.')
param env string = 'demo'

@description('Optional. Specifies the Azure location for all resources.')
param location string = resourceGroup().location

@description('Optional. Service Tier: PerGB2018, Free, Standalone, PerGB or PerNode.')
@allowed([
  'Free'
  'Standalone'
  'PerNode'
  'PerGB2018'
])
param lawSku string = 'PerGB2018'

param deploymentTime string = utcNow()

var locationMapping = {
  eastus: 'e1'
  eastus2: 'e2'
  eastus3: 'e3'
  westus: 'w1'
  westus2: 'w2'
  westus3: 'w3'  
}
var purposeAffix = purpose
var componentNameSuffix = '${purposeAffix}-${env}-${locationMapping[toLower(location)]}'
var componentNameSuffixNoDelimiter = replace(componentNameSuffix, '-', '')
var lawName = 'log-${componentNameSuffix}'
var logicAppiName = 'appi-${componentNameSuffix}-logic'
var logicAppName = 'logic-${componentNameSuffix}'
var logicAppPlanName = 'asp-${componentNameSuffix}-logic'
var logicAppStorageName = 'sta${componentNameSuffixNoDelimiter}logic'
var ediStorageName = 'sta${componentNameSuffixNoDelimiter}edi'

module log 'modules/Microsoft.OperationalInsights/workspaces/deploy.bicep' = {
  name: 'law-${deploymentTime}'
  params: {
    name: lawName
    location: location
    serviceTier: lawSku
    dataRetention: 30
  }
}

module ediStorage 'modules/Microsoft.Storage/storageAccounts/deploy.bicep' = {
  name: 'edista-${deploymentTime}'
  params: {
    location: location
    name: ediStorageName
    enableHierarchicalNamespace: false
    diagnosticWorkspaceId: log.outputs.resourceId
    publicNetworkAccess: 'Enabled'
    systemAssignedIdentity: true
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    blobServices: {
      containers: [
        {
          name: 'contosohealth'
          publicAccess: 'None'
        }
      ]
      diagnosticWorkspaceId: log.outputs.resourceId
    }
  }
}

module logicPlan 'modules/Microsoft.Web/serverfarms/deploy.bicep' = {
  name: 'logicPlan-${deploymentTime}'
  params: {
    name: logicAppPlanName
    diagnosticWorkspaceId: log.outputs.resourceId
    location: location
    sku: {
      name: 'WS1'
      tier: 'WorkflowStandard'
    }
    maximumElasticWorkerCount: 20
    targetWorkerSize: 1
    targetWorkerCount: ((env == 'prod') ? 2 : 1)
    zoneRedundant: false
  }
}

module logicStorage 'modules/Microsoft.Storage/storageAccounts/deploy.bicep' = {
  name: 'logicsta-${deploymentTime}'
  params: {
    location: location
    name: logicAppStorageName
    enableHierarchicalNamespace: false
    diagnosticWorkspaceId: log.outputs.resourceId
    publicNetworkAccess: 'Enabled'
    systemAssignedIdentity: true
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

module logicAppi 'modules/Microsoft.Insights/components/deploy.bicep' = {
  name: 'logicAppi-${deploymentTime}'
  params: {
    name: logicAppiName
    location: location
    workspaceResourceId: log.outputs.resourceId
    kind: 'web'
  }
}

module logic 'modules/FunctionApp/main.bicep' = {
  name: 'logic-${deploymentTime}'
  params: {
    name: logicAppName
    type: 'workflow'
    planId: logicPlan.outputs.resourceId
    storageAccountName: logicStorage.outputs.name
    location: location
    functionExtensionVersion: '~4'
    functionRuntime: 'node'
    workspaceId: log.outputs.resourceId
    enableDiagnostics: true
    enableLogging: true
  }
}
