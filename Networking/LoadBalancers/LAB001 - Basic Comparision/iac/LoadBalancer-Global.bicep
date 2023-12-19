param lbName string
param location string
param backendLbsNames array = []

var lbFrontendPoolName = '${lbName}-frontend'
var lbBackendPoolCrName = '${lbName}-BackendPool'

resource lbPublicIPAddress 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: '${lbName}-ip'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Global'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2023-05-01' = {
  name: lbName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Global'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: lbFrontendPoolName
        properties: {
          publicIPAddress: {
            id: lbPublicIPAddress.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: lbBackendPoolCrName
      }
    ]
    loadBalancingRules: [{
      name: 'LB-80-Rule'
      properties: {
        frontendIPConfiguration: {
          id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', lbName, lbFrontendPoolName)
        }
        backendAddressPool: {
          id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, lbBackendPoolCrName)
        }
        protocol: 'Tcp'
        frontendPort: 80
        backendPort: 80
      }
    }]
  }
}

resource lbBackendPoolCr 'Microsoft.Network/loadBalancers/backendAddressPools@2023-02-01' = {
  name: lbBackendPoolCrName
  parent: loadBalancer
  properties: {
    loadBalancerBackendAddresses: [for (lbName, i) in backendLbsNames: {
      name: '${lbName}-adress'
      properties: {
        loadBalancerFrontendIPConfiguration: {
          id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, '${lbName}-frontend')
        }
      }
    }]
  }
}
