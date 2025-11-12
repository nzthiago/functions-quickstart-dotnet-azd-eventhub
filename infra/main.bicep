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
param apiServiceName string = ''
param apiUserAssignedIdentityName string = ''
param logAnalyticsWorkspaceName string = ''
param resourceGroupName string = ''
param storageAccountName string = ''

// Networking parameters
@description('Enable private networking with VNet integration and private endpoints')
param vnetEnabled bool
param vNetName string = ''

@description('Id of the user identity to be used for testing and debugging. This is not required in production. Leave empty if not needed.')
param principalId string = deployer().objectId

var functionAppName = !empty(apiServiceName) ? apiServiceName : '${abbrs.webSitesFunctions}api-${resourceToken}'
var deploymentStorageContainerName = 'app-package-${take(functionAppName, 32)}-${take(toLower(uniqueString(functionAppName, resourceToken)), 7)}'
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }
var vnetName = !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// User assigned managed identity to be used by the Function App to access Azure resources
module apiUserAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  name: 'apiUserAssignedIdentity'
  scope: rg
  params: {
    name: !empty(apiUserAssignedIdentityName) ? apiUserAssignedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}api-${resourceToken}'
    location: location
    tags: tags
  }
}

// Application Insights for monitoring and logging
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
    allowSharedKeyAccess: false // Disable local authentication methods as per security policy
    dnsEndpointType: 'Standard'
    publicNetworkAccess: vnetEnabled ? 'Disabled' : 'Enabled'
    networkAcls: vnetEnabled ? {
      defaultAction: 'Deny'
      bypass: 'None'
    } : {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    blobServices: {
      containers: [
        {
          name: deploymentStorageContainerName
        }
      ]
    }
    minimumTlsVersion: 'TLS1_2'  // Enforcing TLS 1.2 for better security
    // Role assignments handled by separate rbac.bicep module
  }
}

// Define the configuration object locally to pass to the modules
var storageEndpointConfig = {
  enableBlob: true  // Required for AzureWebJobsStorage, .zip deployment, Event Hubs trigger and Timer trigger checkpointing
  enableQueue: false  // Required for Durable Functions and MCP trigger
  enableTable: false  // Required for Durable Functions and OpenAI triggers and bindings
  enableFiles: false   // Not required, used in legacy scenarios
  allowUserIdentityPrincipal: true   // Allow interactive user identity to access for testing and debugging
}

// Event Hubs namespace and hub for news streaming
module eventHubs './app/eventhubs.bicep' = {
  name: 'eventhubs'
  scope: rg
  params: {
    name: !empty(eventHubNamespaceName) ? eventHubNamespaceName : '${abbrs.eventHubNamespaces}${resourceToken}'
    location: location
    tags: tags
    eventHubName: 'news'
    partitionCount: 32
    retentionInDays: 1
    vnetEnabled: vnetEnabled
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
    enableBlob: storageEndpointConfig.enableBlob
    enableQueue: storageEndpointConfig.enableQueue
    enableTable: storageEndpointConfig.enableTable
    deploymentStorageContainerName: deploymentStorageContainerName
    identityId: apiUserAssignedIdentity.outputs.resourceId
    identityClientId: apiUserAssignedIdentity.outputs.clientId
    virtualNetworkSubnetId: vnetEnabled ? serviceVirtualNetwork.outputs.appSubnetID : ''
    eventHubNamespaceName: eventHubs.outputs.eventHubNamespaceName
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
    eventHubNamespaceName: eventHubs.outputs.eventHubNamespaceName
    applicationInsightsName: monitoring.outputs.name
    managedIdentityPrincipalId: apiUserAssignedIdentity.outputs.principalId
    userIdentityPrincipalId: principalId
    allowUserIdentityPrincipal: storageEndpointConfig.allowUserIdentityPrincipal
    enableBlob: storageEndpointConfig.enableBlob
    enableQueue: storageEndpointConfig.enableQueue
    enableTable: storageEndpointConfig.enableTable
  }
}

// Optional VNet for private networking
module serviceVirtualNetwork './app/vnet.bicep' = if (vnetEnabled) {
  name: 'serviceVirtualNetwork'
  scope: rg
  params: {
    vNetName: vnetName
    location: location
    tags: tags
  }
}

// Storage private endpoints (conditional on VNet being enabled)
module storagePrivateEndpoint './app/storage-PrivateEndpoint.bicep' = if (vnetEnabled) {
  name: 'storagePrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: vnetName
    subnetName: 'private-endpoints-subnet' // Static subnet name from vnet.bicep
    resourceName: storage.outputs.name
    enableBlob: storageEndpointConfig.enableBlob
    enableQueue: storageEndpointConfig.enableQueue
    enableTable: storageEndpointConfig.enableTable
  }
}

// Event Hubs private endpoint (conditional on VNet being enabled)
module eventHubsPrivateEndpoint './app/eventhubs-PrivateEndpoint.bicep' = if (vnetEnabled) {
  name: 'eventHubsPrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    vNetName: vnetName
    eventHubSubnetName: 'eventhub-private-endpoints-subnet' // Static subnet name from vnet.bicep
    eventHubNamespaceId: eventHubs.outputs.eventHubNamespaceId
  }
}

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.connectionString
output APPLICATIONINSIGHTS_NAME string = monitoring.outputs.name
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_CLIENT_ID string = apiUserAssignedIdentity.outputs.clientId
output SERVICE_API_IDENTITY_PRINCIPAL_ID string = apiUserAssignedIdentity.outputs.principalId
output SERVICE_API_NAME string = api.outputs.SERVICE_API_NAME
output SERVICE_API_URI string = 'https://${api.outputs.SERVICE_API_NAME}.azurewebsites.net'
output RESOURCE_GROUP string = rg.name

// EventHubs outputs for local development
output EVENTHUBS_CONNECTION__fullyQualifiedNamespace string = '${eventHubs.outputs.eventHubNamespaceName}.servicebus.windows.net'
