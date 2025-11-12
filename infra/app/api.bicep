param name string
@description('Primary location for all resources & Flex Consumption Function App')
param location string = resourceGroup().location
param tags object = {}
param applicationInsightsName string = ''
param appServicePlanId string
param appSettings array = []
param runtimeName string 
param runtimeVersion string 
param serviceName string = 'api'
param storageAccountName string
param enableBlob bool = true
param enableQueue bool = false
param enableTable bool = false
param deploymentStorageContainerName string
param virtualNetworkSubnetId string = ''
param instanceMemoryMB int = 2048
param maximumInstanceCount int = 100
param identityId string = ''
param identityClientId string = ''
param eventHubNamespaceName string = ''
param eventHubName string = 'news'

var kind = 'functionapp,linux'

resource stg 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  name: applicationInsightsName
}

// Create a Flex Consumption Function App to host the API
module api 'br/public:avm/res/web/site:0.19.3' = {
  name: '${serviceName}-flex-consumption'
  params: {
    kind: kind
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    serverFarmResourceId: appServicePlanId
    managedIdentities: {
      userAssignedResourceIds: [
        identityId
      ]
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${stg.properties.primaryEndpoints.blob}${deploymentStorageContainerName}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: identityId
          }
        }
      }
      scaleAndConcurrency: {
        instanceMemoryMB: instanceMemoryMB
        maximumInstanceCount: maximumInstanceCount
      }
      runtime: {
        name: runtimeName
        version: runtimeVersion
      }
    }
    siteConfig: {
      alwaysOn: false
      appSettings: concat(appSettings, [
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'AzureWebJobsStorage__clientId'
          value: identityClientId
        }
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: stg.properties.primaryEndpoints.blob
        }
      ], enableQueue ? [
        {
          name: 'AzureWebJobsStorage__queueServiceUri'
          value: stg.properties.primaryEndpoints.queue
        }
      ] : [], enableTable ? [
        {
          name: 'AzureWebJobsStorage__tableServiceUri'
          value: stg.properties.primaryEndpoints.table
        }
      ] : [], [
        {
          name: 'EventHubConnection__fullyQualifiedNamespace'
          value: '${eventHubNamespaceName}.servicebus.windows.net'
        }
        {
          name: 'EventHubConnection__clientId'
          value: identityClientId
        }
        {
          name: 'EventHubConnection__credential'
          value: 'managedidentity'
        }
        {
          name: 'EventHubNamespace'
          value: eventHubNamespaceName
        }
        {
          name: 'EventHubName'
          value: eventHubName
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: identityClientId
        }
      ], !empty(applicationInsightsName) ? [
        {
          name: 'APPLICATIONINSIGHTS_AUTHENTICATION_STRING'
          value: 'ClientId=${identityClientId};Authorization=AAD'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.?properties.?ConnectionString ?? ''
        }
      ] : [])
    }
    virtualNetworkSubnetResourceId: !empty(virtualNetworkSubnetId) ? virtualNetworkSubnetId : null
  }
}

output SERVICE_API_NAME string = api.outputs.name
output SERVICE_API_IDENTITY_PRINCIPAL_ID string = ''
