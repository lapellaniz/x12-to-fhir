targetScope = 'subscription'

// ========== //
// Parameters //
// ========== //
@description('Optional. The name of the resource group to deploy for testing purposes.')
@maxLength(90)
param resourceGroupName string = 'ms.web.staticsites-${serviceShort}-rg'

@description('Optional. The location to deploy resources to.')
param location string = deployment().location

@description('Optional. A short identifier for the kind of deployment. Should be kept short to not run into resource-name length-constraints.')
param serviceShort string = 'wsscom'

// =========== //
// Deployments //
// =========== //

// General resources
// =================
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

module resourceGroupResources 'dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, location)}-paramNested'
  params: {
    virtualNetworkName: 'dep-<<namePrefix>>-vnet-${serviceShort}'
    managedIdentityName: 'dep-<<namePrefix>>-msi-${serviceShort}'
    siteName: 'dep-<<namePrefix>>-fa-${serviceShort}'
    serverFarmName: 'dep-<<namePrefix>>-sf-${serviceShort}'
  }
}

// ============== //
// Test Execution //
// ============== //

module testDeployment '../../deploy.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name)}-test-${serviceShort}'
  params: {
    name: '<<namePrefix>>${serviceShort}001'
    allowConfigFileUpdates: true
    enterpriseGradeCdnStatus: 'Disabled'
    lock: 'CanNotDelete'
    privateEndpoints: [
      {
        service: 'staticSites'
        subnetResourceId: resourceGroupResources.outputs.subnetResourceId
        privateDnsZoneGroup: {
          privateDNSResourceIds: [
            resourceGroupResources.outputs.privateDNSZoneResourceId
          ]
        }
      }
    ]
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Reader'
        principalIds: [
          resourceGroupResources.outputs.managedIdentityPrincipalId
        ]
        principalType: 'ServicePrincipal'
      }
    ]
    sku: 'Standard'
    stagingEnvironmentPolicy: 'Enabled'
    systemAssignedIdentity: true
    userAssignedIdentities: {
      '${resourceGroupResources.outputs.managedIdentityResourceId}': {}
    }
    appSettings: {
      foo: 'bar'
      setting: 1
    }
    functionAppSettings: {
      foo: 'bar'
      setting: 1
    }
    linkedBackend: {
      resourceId: resourceGroupResources.outputs.siteResourceId
    }
  }
}
