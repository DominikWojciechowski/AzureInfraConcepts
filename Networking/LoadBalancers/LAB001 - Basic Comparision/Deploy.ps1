param (
    [switch] $All,
    [switch] $TestServices,
    [switch] $LoadBalancer,
    [switch] $ApplicationGateway,
    [switch] $TrafficManager,
    [switch] $FrontDoor,
    [switch] $Cleanup,
    [switch] $Configs
)

if(-Not($All -Or $TestServices -Or $LoadBalancer -Or $ApplicationGateway -Or $TrafficManager -Or $FrontDoor -Or $Cleanup -Or $Configs))
{
    Write-Host "[WARNING] You have to specify mode by adding minimum one of the flags:" -ForegroundColor Yellow
    Write-Host " -All - Deploys all resources" -ForegroundColor Yellow
    Write-Host " -TestServices - Deploys testing services (VMs and WebApps) including infrastructure and application code" -ForegroundColor Yellow
    Write-Host " -LoadBalancer - Deploys Azure Load Balancer (requires TestServices to be deployed)" -ForegroundColor Yellow
    Write-Host " -ApplicationGateway - Deploys Azure Application Gateway (requires TestServices to be deployed)" -ForegroundColor Yellow
    Write-Host " -TrafficManager - Deploys Azure Traffic Manger (requires TestServices to be deployed)" -ForegroundColor Yellow
    Write-Host " -FrontDoor - Deploys Azure FrontDoor (requires TestServices to be deployed)" -ForegroundColor Yellow
    Write-Host " -Cleanup - Removes resource group with all deployed resources" -ForegroundColor Yellow
    Write-Host " -Configs - Load current IP adresses and DNSes" -ForegroundColor Yellow
    return
}

################################################################################################################################
# CONFIGURATIONS
################################################################################################################################

$startTime = Get-Date

# General
$rgName = 'DW-AzureInfraConcepts'
$prefix = 'dwaic'

# VNets
$vNet1 = @{ Name = $prefix + '-vNet-we-001';     Location = 'westeurope'     }
$vNet2 = @{ Name = $prefix + '-vNet-eu-002';     Location = 'eastus'         }
$vNetsList = @($vNet1, $vNet2)

# Web Apps
$webApp1 = @{ Name = $prefix + '-web-we-001';    Location = 'westeurope';       DefaultAvailability='25'        }
$webApp2 = @{ Name = $prefix + '-web-we-002';    Location = 'westeurope';       DefaultAvailability='25'        }
$webAppsList = @($webApp1, $webApp2)

# VMs
$vm1 = @{  Name = $prefix + '-vm-we-001';    Location = 'westeurope';     VNetName=$vNet1.Name;      SubnetName=$vNet1.Name+'-VMs';   DefaultAvailability='25'    }
$vm2 = @{  Name = $prefix + '-vm-we-002';    Location = 'westeurope';     VNetName=$vNet1.Name;      SubnetName=$vNet1.Name+'-VMs';   DefaultAvailability='25'    }
$vm3 = @{  Name = $prefix + '-vm-eu-003';    Location = 'eastus';         VNetName=$vNet2.Name;      SubnetName=$vNet2.Name+'-VMs';   DefaultAvailability='25'    }
$vm4 = @{  Name = $prefix + '-vm-eu-004';    Location = 'eastus';         VNetName=$vNet2.Name;      SubnetName=$vNet2.Name+'-VMs';   DefaultAvailability='25'    }
$vmsList = @($vm1, $vm2, $vm3, $vm4)

$vmAdminUsername = 'TestVmAdmin'
$vmAdminPassword = 'qweQWE123!@#'

# LBs
$lb1Regional =  @{ Name = $prefix + '-lb-regional-we-001';       Location = 'westeurope'    }
$lb2Regional =  @{ Name = $prefix + '-lb-regional-eu-002';       Location = 'eastus'        }
$lb3Global =    @{ Name = $prefix + '-lb-global-eu-003';         Location = 'northeurope'   }

$ag1StandardV2 = @{ Name = $prefix + '-ag-standardv2-we-004';   Location = 'westeurope';    VNetName=$vNet1.Name;      SubnetName=$vNet1.Name+'-LBs';   }
$ag2StandardV2 = @{ Name = $prefix + '-ag-standardv2-eu-005';   Location = 'eastus';        VNetName=$vNet2.Name;      SubnetName=$vNet2.Name+'-LBs';   }

$tm1 = @{ Name = $prefix + '-tm-global-006'; }

$fd1 = @{ Name = $prefix + '-fd-global-007'; }

# Resource group creation 
Write-Host " - Creating resource group in Azure" -ForegroundColor Blue
az group create --name $rgName --location "westeurope"

################################################################################################################################
# TEST SERVICES
################################################################################################################################
if($All -Or $TestServices)
{
    # TEST APPLICATION

    Write-Host " - Building deployment package" -ForegroundColor Blue
    dotnet publish .\src\DW.AzureInfraConcepts.AvailabilityTestApp -c Debug -f net8.0 -o ./tmp/publish
    Compress-Archive .\tmp\publish\* .\tmp\publish.zip -Force
    
    # NETWORKING
    foreach ($vNet in $vNetsList) 
    {
        Write-Host " - NETWORKING - $($vNet.Name) - Deploying infrastructure" -ForegroundColor Blue
        az deployment group create --resource-group $rgName --template-file .\iac\vNet.bicep --mode Incremental --parameters vNetName=$($vNet.Name) location=$($vNet.Location)
    }

    # TEST WEB APPS
    foreach ($webApp in $webAppsList) 
    {
        Write-Host " - WEB APPS - $($webApp.Name) - Deploying infrastructure" -ForegroundColor Blue
        az deployment group create --resource-group $rgName --template-file .\iac\TestWebApp.bicep --mode Incremental --parameters appName=$($webApp.Name) location=$($webApp.Location)

        Write-Host " - WEB APPS - $($webApp.Name) - Deploying code" -ForegroundColor Blue
        az webapp deploy --resource-group $rgName --name $($webApp.Name) --src-path .\tmp\publish.zip --type zip

        Write-Host " - WEB APPS - $($webApp.Name) - Configuration" -ForegroundColor Blue
        az webapp config appsettings set --resource-group $rgName --name $($webApp.Name) --settings ApplicationOptions__AppName=$($webApp.Name)
        az webapp config appsettings set --resource-group $rgName --name $($webApp.Name) --settings ApplicationOptions__FailurePercentage=$($webApp.DefaultAvailability)
    }

    # TEST VMS
    if(-not(Test-path $HOME\.ssh\id_rsa -PathType leaf)) {
        echo y | ssh-keygen -m PEM -t rsa -b 2048 -q -N '""' -f $HOME\.ssh\id_rsa
    }

    foreach ($vm in $vmsList) 
    {
        Write-Host " - VMs - $($vm.Name) - Deploying infrastructure" -ForegroundColor Blue
        az deployment group create --resource-group $rgName --template-file .\iac\TestVM.bicep --mode Incremental --parameters vmName=$($vm.Name) location=$($vm.Location) virtualNetworkName=$($vm.VNetName) subnetName=$($vm.SubnetName) adminUsername=$vmAdminUsername adminPassword=$vmAdminPassword

        Write-Host " - VMs - $($vm.Name) - Deploying code and configuration" -ForegroundColor Blue
        # Enabling SSH connection
        az vm run-command invoke -g $rgName -n $($vm.Name) --command-id RunPowerShellScript --scripts "'$(Get-Content ~/.ssh/id_rsa.pub)' | Add-Content 'C:\ProgramData\ssh\administrators_authorized_keys' -Encoding UTF8;icacls.exe 'C:\ProgramData\ssh\administrators_authorized_keys' /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F'"
        # Upload code
        $vmIpAdress =  az vm show -d -g $rgName -n $($vm.Name) --query publicIps
        scp -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -r .\tmp\publish\* ($vmAdminUsername+'@'+$vmIpAdress+':/C:/inetpub/wwwroot')
        # Set env variables for IIS
        az vm run-command invoke -g $rgName -n $($vm.Name) --command-id RunPowerShellScript --scripts "Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter 'system.webServer/aspNetCore/environmentVariables' -name '.' -value @{name='ApplicationOptions__AppName';value='$($vm.Name)'} -force"
        az vm run-command invoke -g $rgName -n $($vm.Name) --command-id RunPowerShellScript --scripts "Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter 'system.webServer/aspNetCore/environmentVariables' -name '.' -value @{name='ApplicationOptions__FailurePercentage';value='$($vm.DefaultAvailability)'} -force"
    }

    # Cleanup
    Write-Host " - Cleaning" -ForegroundColor Blue
    rm tmp -r
}

################################################################################################################################
# LOAD BALANCERS
################################################################################################################################
if($All -Or $LoadBalancer)
{
    # STANDARD LOAD BALANCER - LOCAL 
    Write-Host " - LOAD BALANCER - REGIONAL - Deploying" -ForegroundColor Blue
    $vmsNamesForStandardLB_1 = $('[\"' + (@($($vm1.Name), $($vm2.Name)) -join '\",\"') + '\"]')
    az deployment group create --resource-group $rgName --template-file .\iac\LoadBalancer-Regional.bicep --mode Incremental --parameters lbName=$($lb1Regional.Name) location=$($lb1Regional.Location) vmNames=$vmsNamesForStandardLB_1

    $vmsNamesForStandardLB_2 = $('[\"' + (@($($vm3.Name), $($vm4.Name)) -join '\",\"') + '\"]')
    az deployment group create --resource-group $rgName --template-file .\iac\LoadBalancer-Regional.bicep --mode Incremental --parameters lbName=$($lb2Regional.Name) location=$($lb2Regional.Location) vmNames=$vmsNamesForStandardLB_2

    # STANDARD LOAD BALANCER - GLOBAL
    Write-Host " - LOAD BALANCER - GLOBAL - Deploying" -ForegroundColor Blue
    $lbStandardForGlobalLB = $('[\"' + (@($($lb1Regional.Name), $($lb2Regional.Name)) -join '\",\"') + '\"]')
    az deployment group create --resource-group $rgName --template-file .\iac\LoadBalancer-Global.bicep --mode Incremental --parameters lbName=$($lb3Global.Name) location=$($lb3Global.Location) backendLbsNames=$lbStandardForGlobalLB
}

################################################################################################################################
# APPLICATION GATEWAY
################################################################################################################################
if($All -Or $ApplicationGateway)
{
    Write-Host " - APPLICATION GATEWAY - STANDARD V2 - Configure NSG" -ForegroundColor Blue
    az network nsg rule create --resource-group $rgName --nsg-name $($vNet1.Name + '-NetworkSecurityGroup') --name 'AllowApplicationGatewayTraffic' --priority 1100 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges '65200-65535'
    az network nsg rule create --resource-group $rgName --nsg-name $($vNet2.Name + '-NetworkSecurityGroup') --name 'AllowApplicationGatewayTraffic' --priority 1100 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges '65200-65535'

    Write-Host " - APPLICATION GATEWAY - STANDARD V2 - EU - Deploying" -ForegroundColor Blue
    $vmsNamesForAppGatewayStandardV2_EU = $('[\"' + (@($($vm1.Name), $($vm2.Name)) -join '\",\"') + '\"]')
    $webAppAddressesForAppGatewayStandardV2_EU = $('[\"' + (@(($($webApp1.Name)+'.azurewebsites.net'), ($($webApp2.Name)+'.azurewebsites.net')) -join '\",\"') + '\"]')
    az deployment group create --resource-group $rgName --template-file .\iac\ApplicationGateway-WAFV2.bicep --mode Incremental --parameters agName=$($ag1StandardV2.Name) location=$($ag1StandardV2.Location) virtualNetworkName=$($ag1StandardV2.VNetName) subnetName=$($ag1StandardV2.SubnetName) vmNames=$vmsNamesForAppGatewayStandardV2_EU webAppAddresses=$webAppAddressesForAppGatewayStandardV2_EU

    Write-Host " - APPLICATION GATEWAY - STANDARD V2 - US - Deploying" -ForegroundColor Blue
    $vmsNamesForAppGatewayStandardV2_US = $('[\"' + (@($($vm3.Name), $($vm4.Name)) -join '\",\"') + '\"]')
    $webAppAddressesForAppGatewayStandardV2_US = '[]'
    az deployment group create --resource-group $rgName --template-file .\iac\ApplicationGateway-WAFV2.bicep --mode Incremental --parameters agName=$($ag2StandardV2.Name) location=$($ag2StandardV2.Location) virtualNetworkName=$($ag2StandardV2.VNetName) subnetName=$($ag2StandardV2.SubnetName) vmNames=$vmsNamesForAppGatewayStandardV2_US webAppAddresses=$webAppAddressesForAppGatewayStandardV2_US
}

################################################################################################################################
# TRAFFIC MANAGER
################################################################################################################################
if($All -Or $TrafficManager)
{
    Write-Host " - TRAFFIC MANAGER - Deploying" -ForegroundColor Blue
    az deployment group create --resource-group $rgName --template-file .\iac\TrafficManager.bicep --mode Incremental --parameters name=$($tm1.Name) euPublicIPName=$($lb1Regional.Name + '-ip') usPublicIPName=$($lb2Regional.Name + '-ip')
}

################################################################################################################################
# FRONT DOOR
################################################################################################################################
if($All -Or $FrontDoor)
{
    Write-Host " - FRONT DOOR - Deploying" -ForegroundColor Blue
    az deployment group create --resource-group $rgName --template-file .\iac\FrontDoor.bicep --mode Incremental --parameters name=$($fd1.Name) euPublicIPName=$($lb1Regional.Name + '-ip') usPublicIPName=$($lb2Regional.Name + '-ip')
}

################################################################################################################################
# CLEANUP
################################################################################################################################
if($Cleanup)
{
    # Remove resource group
    Write-Host " - Cleanup - Removing resource group with resources" -ForegroundColor DarkYellow
    az group delete --resource-group $rgName --yes
}

################################################################################################################################
# SUMMARY AND GET ALL CONFIGURATIONS
################################################################################################################################

# Summary
$endTime = Get-Date
$executionTime = $endTime - $startTime
Write-Host " - DEPLOYMENT COMPLETED - execution time $executionTime" -ForegroundColor Green

# Configurations
Write-Host " - CONFIGS - Getting all configurations" -ForegroundColor Blue
$ipLBRegionalEU = az network public-ip list --query $("[?name=='"+$($lb1Regional.Name)+"-ip'].{IP:ipAddress}") --output tsv 
$ipLBRegionalUS = az network public-ip list --query $("[?name=='"+$($lb2Regional.Name)+"-ip'].{IP:ipAddress}") --output tsv 
$ipLBGlobal = az network public-ip list --query $("[?name=='"+$($lb3Global.Name)+"-ip'].{IP:ipAddress}") --output tsv 
$ipAGRegionalEU = az network public-ip list --query $("[?name=='"+$($ag1StandardV2.Name)+"-ip'].{IP:ipAddress}") --output tsv
$ipAGRegionalUS = az network public-ip list --query $("[?name=='"+$($ag2StandardV2.Name)+"-ip'].{IP:ipAddress}") --output tsv
$dnsTrafficManager = az network traffic-manager profile show --name $($tm1.Name) --resource-group $rgName --query "dnsConfig.fqdn" --output tsv
$dnsFrontDoor = az afd endpoint list -g $rgName --profile-name $($fd1.Name) --query "[0].hostName" --output tsv

Write-Host " - Load Balancer - Regional EU - " $ipLBRegionalEU -ForegroundColor Gray
Write-Host " - Load Balancer - Regional US - " $ipLBRegionalUS -ForegroundColor Gray
Write-Host " - Load Balancer - Global      - " $ipLBGlobal -ForegroundColor Gray
Write-Host " - Application Gateway - EU    - " $ipAGRegionalEU -ForegroundColor Gray
Write-Host " - Application Gateway - US    - " $ipAGRegionalUS -ForegroundColor Gray
Write-Host " - Traffic Manger              - " $dnsTrafficManager -ForegroundColor Gray
Write-Host " - Front Door                  - " $dnsFrontDoor -ForegroundColor Gray