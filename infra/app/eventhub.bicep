param name string
param location string = resourceGroup().location
param tags object = {}
param eventHubName string = 'news'
param partitionCount int = 32
param retentionInDays int = 1
param vnetEnabled bool

// Create EventHub namespace using Azure Verified Module
module eventHubNamespace 'br/public:avm/res/event-hub/namespace:0.7.1' = {
  name: 'eventhub-namespace'
  params: {
    name: name
    location: location
    tags: tags
    skuName: 'Standard'
    eventhubs: [
      {
        name: eventHubName
        partitionCount: partitionCount
        retentionDescription: {
          retentionTimeInHours: retentionInDays * 24
        }
      }
    ]
    publicNetworkAccess: vnetEnabled ? 'Disabled' : 'Enabled'
  }
}

output eventHubNamespaceName string = eventHubNamespace.outputs.name
output eventHubNamespaceId string = eventHubNamespace.outputs.resourceId
