param appName string
param location string

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${appName}-plan'
  location: location
  sku: {
    name: 'B1'
  }
  properties: {
    reserved: false
  }
  kind: 'windows'
}

resource appService 'Microsoft.Web/sites@2022-09-01' = {
  name: appName
  location: location
  properties: {
    serverFarmId: appServicePlan.id  
    siteConfig: { 
      metadata :[
        {
          name:'CURRENT_STACK'
          value:'dotnet'
        }
      ]
      netFrameworkVersion: 'v8.0'
    }
  }
}
