param agName string
param location string
param virtualNetworkName string
param subnetName string
param vmNames array
param webAppAddresses array

var agGatewayIPConfigurationName = '${agName}-Gateway'
var agFrontendIPConfigurationName = '${agName}-Frontend'
var agBackendPoolName = '${agName}-BackendPool'

resource agPublicIPAddress 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: '${agName}-ip'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource appGateway 'Microsoft.Network/applicationGateways@2023-05-01' = {
  name: agName
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    gatewayIPConfigurations: [
      {
        name: agGatewayIPConfigurationName
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: agFrontendIPConfigurationName
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: agPublicIPAddress.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: agBackendPoolName
        properties: {
          backendAddresses: [for (webAppAddress, i) in webAppAddresses: {
            fqdn: webAppAddress
          }]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'HTTPSetting'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Enabled'
          affinityCookieName: 'ApplicationGatewayAffinity'
          pickHostNameFromBackendAddress: true
          requestTimeout: 20
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', agName, 'lbprobe')
          }
          probeEnabled: true
        }
      }
    ]
    httpListeners: [
      {
        name: 'frontHTTPListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', agName, agFrontendIPConfigurationName)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', agName, 'port_80')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'HTTPRoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', agName, 'frontHTTPListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', agName, agBackendPoolName)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', agName, 'HTTPSetting')
          }
        }
      }
    ]
    enableHttp2: false
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 2
    }
    probes: [
      {
        name: 'lbprobe'
        properties: {
          protocol: 'Http'
          host: null
          port: 80
          path: '/_health'
          pickHostNameFromBackendHttpSettings: true
          interval: 15
          unhealthyThreshold: 2
          timeout: 30
        }
      }
    ]
    firewallPolicy: {
      id: appGatewayFirewallPolicy.id
    }
  }
}

resource appGatewayFirewallPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2021-08-01' = {
  name: '${agName}-FirewallPolicy'
  location: location
  properties: {
    policySettings: {
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
      state: 'Enabled'
      mode: 'Prevention'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.1'
        }
      ]
    }
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
              applicationGatewayBackendAddressPools: [
              {
                id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', agName, agBackendPoolName)
              }
            ]
          }
        )
      }
    ]
  }
  dependsOn: [
    appGateway
  ]
}]
