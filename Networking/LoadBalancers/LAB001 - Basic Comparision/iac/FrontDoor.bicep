param name string
param euPublicIPName string
param usPublicIPName string

resource frontDoorProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: name
  location: 'global'
  sku: {
    name: 'Standard_AzureFrontDoor'    // Standard_AzureFrontDoor or Premium_AzureFrontDoor
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = {
  name: 'AFD-DefaultEndpoint'
  parent: frontDoorProfile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
  name: 'GlobalLoadBalancers'
  parent: frontDoorProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 100
    }
    healthProbeSettings: {
      probePath: '/_health'
      probeRequestType: 'GET'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 60
    }
  }
}

resource frontDoorOriginUS 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
  name: 'US-Servers'
  parent: frontDoorOriginGroup
  properties: {
    hostName: usPublicIP.properties.ipAddress
    originHostHeader: usPublicIP.properties.ipAddress
    httpPort: 80
    httpsPort: 443
    priority: 1
    weight: 1000
  }
}

resource frontDoorOriginEU 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
  name: 'EU-Servers'
  parent: frontDoorOriginGroup
  properties: {
    hostName: euPublicIP.properties.ipAddress
    originHostHeader: euPublicIP.properties.ipAddress
    httpPort: 80
    httpsPort: 443
    priority: 1
    weight: 1000
  }
}

resource euPublicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' existing = {
  name: euPublicIPName
}

resource usPublicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' existing = {
  name: usPublicIPName
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  name: 'Route-EUandUSBalancing'
  parent: frontDoorEndpoint
  dependsOn: [
    frontDoorOriginUS
    frontDoorOriginEU
  ]
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'MatchRequest'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Disabled'
  }
}
