param lbName string
param location string
param vmNames array = []

var lbFrontendPoolName = '${lbName}-frontend'

resource lbPublicIPAddress 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: '${lbName}-ip'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: lbName
    }
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2023-05-01' = {
  name: lbName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
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
        name: 'VMs-BackendPool'
      }
    ]
    loadBalancingRules: [{
      name: 'VM-80-Rule'
      properties: {
        frontendIPConfiguration: {
          id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', lbName, lbFrontendPoolName)
        }
        backendAddressPool: {
          id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'VMs-BackendPool')
        }
        probe: {
          id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, 'lbprobe')
        } 
        protocol: 'Tcp'
        frontendPort: 80
        backendPort: 80
        idleTimeoutInMinutes: 15
      }
    }]
    probes: [
      {
        properties: {
          protocol: 'HTTP'
          requestPath: '/_health'
          port: 80
          intervalInSeconds: 15
          probeThreshold: 2
        }
        name: 'lbprobe'
      }
    ]
  }
}

module getCurrentNICIPConfigurations 'NIC-ExistingIPConfigurations.bicep' = [for (vmName, i) in vmNames: {
  name: '${vmName}-getCurrentNICIPConfigurations'
  params: {
    nicName: '${vmName}-NetworkInterface'
  }
}]

resource networkInterface 'Microsoft.Network/networkInterfaces@2023-05-01' =  [for (vmName, i) in vmNames: {
  name: '${vmName}-NetworkInterface'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: getCurrentNICIPConfigurations[i].outputs.configurations[0].name
        properties: union(
          getCurrentNICIPConfigurations[i].outputs.configurations[0].properties, 
          {
            loadBalancerBackendAddressPools: [
              {
                id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'VMs-BackendPool')
              }
            ]
          }
        )
      }
    ]
  }
  dependsOn: [
    loadBalancer
  ]
}]
