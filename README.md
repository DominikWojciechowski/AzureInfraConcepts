# Azure Infra Concepts

<table>
    <thead>
        <tr>
            <th>Code examples <br /><br /><a href="https://github.com/DominikWojciechowski/AzureInfraConcepts">GitHub Code</a></th>
            <th>Documentation <br /><br /><a href="https://github.com/DominikWojciechowski/AzureInfraConcepts/wiki">GitHub Wiki</a></th>
        </tr>
    </thead>
</table>


# How to start

1. Clone repository
2. Open main folder and navigate to specyfic directory you would like to test
3. In the target directory you will find README.md file which will describe in details usage for each scenario

**Pre-requisities**
1. Make sure Azure CLI is installed 
    > Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
2. Make sure Bicep tools are installed
    > az bicep install