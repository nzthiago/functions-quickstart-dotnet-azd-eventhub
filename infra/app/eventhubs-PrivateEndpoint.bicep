@description('Creates a private endpoint to EventHub in the eventHubSubnet.')
param eventHubNamespaceId string
param vNetName string
param eventHubSubnetName string
param location string = resourceGroup().location
param tags object = {}

var eventHubPrivateDnsZoneName = 'privatelink.servicebus.windows.net'

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: vNetName
}

// EventHub Private DNS Zone
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: eventHubPrivateDnsZoneName
  location: 'global'
  tags: tags
}

// Link DNS zone to VNet
resource dnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${vNetName}-eventhub-link'
  parent: privateDnsZone
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
  tags: tags
}

resource eventHubSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  parent: vnet
  name: eventHubSubnetName
}

resource eventHubPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: 'eventhub-private-endpoint'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: eventHubSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'eventhub-connection'
        properties: {
          privateLinkServiceId: eventHubNamespaceId
          groupIds: ['namespace']
        }
      }
    ]
  }
  dependsOn: [
    privateDnsZone
    dnsZoneVnetLink
  ]
}

// DNS Zone Group to automatically create A records
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-09-01' = {
  name: 'default'
  parent: eventHubPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

output privateEndpointId string = eventHubPrivateEndpoint.id
