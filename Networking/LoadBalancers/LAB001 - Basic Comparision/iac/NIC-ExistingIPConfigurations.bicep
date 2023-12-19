param nicName string

resource networkInterfaces 'Microsoft.Network/networkInterfaces@2023-05-01' existing =  {
  name: nicName
}

output configurations array = networkInterfaces.properties.ipConfigurations
