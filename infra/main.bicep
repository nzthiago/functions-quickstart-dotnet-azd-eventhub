targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@metadata({
  azd: {
    type: 'location'
  }
})
param location string


var abbrs = loadJsonContent('./abbreviations.json')

// Optional parameters
param applicationInsightsName string = ''
param appServicePlanName string = ''
param eventHubNamespaceName string = ''
param functionAppServiceName string = ''
param logAnalyticsWorkspaceName string = ''
param resourceGroupName string = ''
param storageAccountName string = ''

// Networking parameters
@description('Enable private networking with VNet integration and private endpoints')
param enablePrivateNetworking bool = false
param vNetName string = ''

@description('Id of the user identity to be used for testing and debugging. This is not required in production. Leave empty if not needed.')
param principalId string = deployer().objectId

var functionAppName = !empty(functionAppServiceName) ? functionAppServiceName : '${abbrs.webSitesFunctions}${resourceToken}'
var deploymentStorageContainerName = 'app-package-${take(functionAppName, 32)}-${take(resourceToken, 7)}'
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// User assigned managed identity to be used by the Function App to access Azure resources
module managedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  name: 'identity'
  scope: rg
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}'
    location: location
    tags: tags
  }
}

// Storage account to host function code and for logging
module storage 'br/public:avm/res/storage/storage-account:0.13.2' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    blobServices: {
      containers: [
        {
          name: deploymentStorageContainerName
        }
      ]
    }
    // Role assignments handled by separate rbac.bicep module
  }
}

// Application Insights for monitoring and logging
module monitoring 'br/public:avm/res/insights/component:0.4.1' = {
  name: 'monitoring'
  scope: rg
  params: {
    name: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    location: location
    tags: tags
    workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
    disableLocalAuth: true
    kind: 'web'
    applicationType: 'web'
    // Role assignments handled by separate rbac.bicep module
  }
}

module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.7.0' = {
  name: 'loganalytics'
  scope: rg
  params: {
    name: !empty(logAnalyticsWorkspaceName) ? logAnalyticsWorkspaceName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
    dataRetention: 30
  }
}

// Event Hub namespace and hub for news streaming
module eventHub './app/eventhub.bicep' = {
  name: 'eventhub'
  scope: rg
  params: {
    name: !empty(eventHubNamespaceName) ? eventHubNamespaceName : '${abbrs.eventHubNamespaces}${resourceToken}'
    location: location
    tags: tags
    eventHubName: 'news'
    partitionCount: 32
    retentionInDays: 1
  }
}

// App service plan to host the function app
module appServicePlan 'br/public:avm/res/web/serverfarm:0.5.0' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    skuName: 'FC1' // Flex Consumption
    reserved: true
  }
}

// The function app
module api './app/api.bicep' = {
  name: 'api'
  scope: rg
  params: {
    name: !empty(functionAppName) ? functionAppName : '${abbrs.webSitesFunctions}${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.name
    appServicePlanId: appServicePlan.outputs.resourceId
    runtimeName: 'dotnet-isolated'
    runtimeVersion: '8.0'
    storageAccountName: storage.outputs.name
    deploymentStorageContainerName: deploymentStorageContainerName
    identityId: managedIdentity.outputs.resourceId
    identityClientId: managedIdentity.outputs.clientId
    virtualNetworkSubnetId: ''
    eventHubNamespaceName: eventHub.outputs.eventHubNamespaceName
    eventHubName: 'news'
    appSettings: []
  }
}

// Role assignments for the managed identity to access resources
module apiRoleAssignments './app/rbac.bicep' = {
  name: 'rbac'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    eventHubNamespaceName: eventHub.outputs.eventHubNamespaceName
    applicationInsightsName: monitoring.outputs.name
    managedIdentityPrincipalId: managedIdentity.outputs.principalId
    userIdentityPrincipalId: principalId
    allowUserIdentityPrincipal: true // Enable for deployment permissions
    enableBlob: true
  }
}

// Optional VNet for private networking
module vnet './app/vnet.bicep' = if (enablePrivateNetworking) {
  name: 'vnet'
  scope: rg
  params: {
    vNetName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    location: location
    tags: tags
  }
}

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.connectionString
output APPLICATIONINSIGHTS_NAME string = monitoring.outputs.name
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_CLIENT_ID string = managedIdentity.outputs.clientId
output SERVICE_API_IDENTITY_PRINCIPAL_ID string = managedIdentity.outputs.principalId
output SERVICE_API_NAME string = api.outputs.SERVICE_API_NAME
output SERVICE_API_URI string = 'https://${api.outputs.SERVICE_API_NAME}.azurewebsites.net'

// EventHub outputs for local development
output EVENTHUB_CONNECTION__fullyQualifiedNamespace string = '${eventHub.outputs.eventHubNamespaceName}.servicebus.windows.net'
output EVENTHUB_NAME string = 'news'
