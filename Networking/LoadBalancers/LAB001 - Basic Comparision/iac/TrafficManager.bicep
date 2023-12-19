param name string
param euPublicIPName string
param usPublicIPName string

resource trafficManagerProfile 'Microsoft.Network/trafficmanagerprofiles@2018-08-01' = {
  name: name
  location: 'global'
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Performance'  // Performance, Priority, Geographic, Subnet, Weighted, MultiValue
    dnsConfig: {
      relativeName: name
      ttl: 30
    }
    monitorConfig: {
      protocol: 'HTTP'
      port: 80
      path: '/_health'
      expectedStatusCodeRanges: [
        {
          min: 200
          max: 202
        }
      ]
    }
    endpoints: [
      {
        type: 'Microsoft.Network/TrafficManagerProfiles/AzureEndpoints'
        name: 'Europe'
        properties: {
          targetResourceId: euPublicIP.id
          target: euPublicIP.properties.dnsSettings.fqdn
        }
      }
      {
        type: 'Microsoft.Network/TrafficManagerProfiles/AzureEndpoints'
        name: 'US'
        properties: {
          targetResourceId: usPublicIP.id
          target: usPublicIP.properties.dnsSettings.fqdn
        }
      }
    ]
  }
}

resource euPublicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' existing = {
  name: euPublicIPName
}

resource usPublicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' existing = {
  name: usPublicIPName
}
