param virtualNetworkName string
param subnetName string
@description('Specifies the storage account resource name')
param resourceName string
param location string = resourceGroup().location
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2021-08-01' existing = {
  name: virtualNetworkName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: resourceName
}

// Storage DNS zone names
var blobPrivateDNSZoneName = 'privatelink.blob.${environment().suffixes.storage}'
var tablePrivateDNSZoneName = 'privatelink.table.${environment().suffixes.storage}'
var queuePrivateDNSZoneName = 'privatelink.queue.${environment().suffixes.storage}'

// AVM module for Blob Private DNS Zone
module privateDnsZoneBlobDeployment 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  name: 'blob-private-dns-zone-deployment'
  params: {
    name: blobPrivateDNSZoneName
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        name: '${resourceName}-blob-link-${take(toLower(uniqueString(resourceName, virtualNetworkName)), 4)}'
        virtualNetworkResourceId: vnet.id
        registrationEnabled: false
        location: 'global'
        tags: tags
      }
    ]
  }
}

// AVM module for Table Private DNS Zone
module privateDnsZoneTableDeployment 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  name: 'table-private-dns-zone-deployment'
  params: {
    name: tablePrivateDNSZoneName
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        name: '${resourceName}-table-link-${take(toLower(uniqueString(resourceName, virtualNetworkName)), 4)}'
        virtualNetworkResourceId: vnet.id
        registrationEnabled: false
        location: 'global'
        tags: tags
      }
    ]
  }
}

// AVM module for Queue Private DNS Zone
module privateDnsZoneQueueDeployment 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  name: 'queue-private-dns-zone-deployment'
  params: {
    name: queuePrivateDNSZoneName
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        name: '${resourceName}-queue-link-${take(toLower(uniqueString(resourceName, virtualNetworkName)), 4)}'
        virtualNetworkResourceId: vnet.id
        registrationEnabled: false
        location: 'global'
        tags: tags
      }
    ]
  }
}

// AVM module for Blob Private Endpoint
module blobPrivateEndpoint 'br/public:avm/res/network/private-endpoint:0.11.0' = {
  name: 'blob-private-endpoint-deployment'
  params: {
    name: 'blob-private-endpoint'
    location: location
    tags: tags
    subnetResourceId: '${vnet.id}/subnets/${subnetName}'
    privateLinkServiceConnections: [
      {
        name: 'blobPrivateLinkConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    customDnsConfigs: []
    privateDnsZoneGroup: {
      privateDnsZoneGroupConfigs: [
        {
          name: 'storageBlobARecord'
          privateDnsZoneResourceId: privateDnsZoneBlobDeployment.outputs.resourceId
        }
      ]
    }
  }
}

// AVM module for Table Private Endpoint
module tablePrivateEndpoint 'br/public:avm/res/network/private-endpoint:0.11.0' = {
  name: 'table-private-endpoint-deployment'
  params: {
    name: 'table-private-endpoint'
    location: location
    tags: tags
    subnetResourceId: '${vnet.id}/subnets/${subnetName}'
    privateLinkServiceConnections: [
      {
        name: 'tablePrivateLinkConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'table'
          ]
        }
      }
    ]
    customDnsConfigs: []
    privateDnsZoneGroup: {
      privateDnsZoneGroupConfigs: [
        {
          name: 'storageTableARecord'
          privateDnsZoneResourceId: privateDnsZoneTableDeployment.outputs.resourceId
        }
      ]
    }
  }
}

// AVM module for Queue Private Endpoint
module queuePrivateEndpoint 'br/public:avm/res/network/private-endpoint:0.11.0' = {
  name: 'queue-private-endpoint-deployment'
  params: {
    name: 'queue-private-endpoint'
    location: location
    tags: tags
    subnetResourceId: '${vnet.id}/subnets/${subnetName}'
    privateLinkServiceConnections: [
      {
        name: 'queuePrivateLinkConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'queue'
          ]
        }
      }
    ]
    customDnsConfigs: []
    privateDnsZoneGroup: {
      privateDnsZoneGroupConfigs: [
        {
          name: 'storageQueueARecord'
          privateDnsZoneResourceId: privateDnsZoneQueueDeployment.outputs.resourceId
        }
      ]
    }
  }
}
