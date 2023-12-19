# NOTE: Specify the target URL
# You can put here publicly available IP address or DNS for VM, Load Balancer, Traffic Manger, Application Gateway or Front Door
$url = "http://afd-defaultendpoint-fhdsesembfdageey.z03.azurefd.net/_health"

$colorMap = @('Green', 'Yellow', 'Blue', 'Magenta', 'Cyan', 'DarkGray', 'DarkYellow', 'DarkMagenta', 'DarkCyan', 'Red')

for ($i = 1; $true; $i++) {

    # This script block makes sure that each request is established as a new connection - so that session affinity is not redirecting always to the same server.
    Start-Job -ScriptBlock {  $url = $Using:url; Invoke-RestMethod $url  } -Name HealthCheck | Out-Null

    $jsonData = Receive-Job HealthCheck -Wait

    $lastThreeChars = $jsonData.instance.Substring($jsonData.instance.Length - 3)
    $number = [int]$lastThreeChars

    Write-Host "$i - Information received from the server: $($jsonData.instance) with status '$($jsonData.status)'" -ForegroundColor $colorMap[$number - 1]

    Start-Sleep -Seconds 1
}