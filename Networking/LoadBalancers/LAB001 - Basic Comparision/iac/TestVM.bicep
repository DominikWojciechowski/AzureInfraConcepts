param vmName string
param location string
param virtualNetworkName string
param subnetName string

@secure()
param adminPassword string
param adminUsername string

var subnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)

resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5'
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    } 
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vmName}-NetworkInterface'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'vm-ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetRef
          }
          publicIPAddress: {
            id: vmPublicIPAddress.id
          }
          primary: true
        }
      }
    ]
  }
}

// OPTIONAL: Allows connect to VM via RDP by exposing IP to external world
resource vmPublicIPAddress 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: '${vmName}-VMPublicIp'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// CONFIGURATION: Enables IIS
resource vmIISConfiguration 'Microsoft.Compute/virtualMachines/runCommands@2022-03-01' = {
  name: 'vm-IISConfiguration-Script'
  location: location
  parent: vm
  properties: {
    asyncExecution: false
    parameters: [
      {
        name: 'vmName'
        value: vmName
      }
      {
        name: 'failurePercentage'
        value: '25'
      }
    ]
    source: {
      script: '''
        param(
          $vmName,
          $failurePercentage
        )

        try {
          # Enable IIS
          Install-WindowsFeature -name Web-Server -IncludeManagementTools
          
          # Install ASP.NET Core Runtime - Windows Hosting Bundle
          $installerUrl = "https://download.visualstudio.microsoft.com/download/pr/2a7ae819-fbc4-4611-a1ba-f3b072d4ea25/32f3b931550f7b315d9827d564202eeb/dotnet-hosting-8.0.0-win.exe"
          $installerOutputFile = [Environment]::GetFolderPath("Desktop") + "\dotnet-hosting.exe"
          Invoke-WebRequest -Uri $installerUrl -OutFile $installerOutputFile 
          Start-Process -Wait -FilePath $installerOutputFile -ArgumentList "/S" -PassThru
        
          # Cleanup
          Remove-Item C:\\inetpub\\wwwroot\\iisstart.htm
          Remove-Item C:\\inetpub\\wwwroot\\iisstart.png

          # Restart server
          net stop was /y
          net start w3svc
        }
        catch {
            $errorDetails = $_.Exception | Format-List | Out-String
            $errorDetails | Out-File -FilePath "error.log" -Append
            # NOTE: Logs can be found under: 'C:\Packages\Plugins\Microsoft.CPlat.Core.RunCommandHandlerWindows\2.0.8\Downloads'
        }
      '''
    }
  }
}

// OPTIONAL: SSH extention to deploy code from local machine
resource extension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  name: 'vm-WindowsOpenSSH-extension'
  parent: vm
  location: location
  properties: {
    publisher: 'Microsoft.Azure.OpenSSH'
    type: 'WindowsOpenSSH'
    typeHandlerVersion: '3.0'
    autoUpgradeMinorVersion: true
  }
}
