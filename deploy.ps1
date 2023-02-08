
[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $prefix,

    [Parameter()]
    [string]
    $location = "eastus"
)


$resourceGroupName = $prefix + "-rg"
$aksClusterName = $prefix + "-aks"
$aksVnet = $prefix + "-vnet"
$aksSubnet = "akssubnet"
$appGwSubnet = "appgwsubnet"
$logAnalyticsWorkspace = $prefix + "-log"
$acrName = $prefix + "acr"
$podLabel = "downloaderpod:latest"
$nsgName = $prefix + "-nsg"
$appGwNsg = $prefix + "-appgw-nsg"
$publicIPName = $prefix + "-pip"
$appGatewayName = $prefix + "-appgw"
$storageAccountName = $prefix + "sa"
$containerName = "largefile"



Write-Host "Creating Resource Group: $resourceGroupName" -ForegroundColor DarkGreen
az group create --name $resourceGroupName --location $location -o table

Write-Host "Creating Log Analytics Workspace: $logAnalyticsWorkspace" -ForegroundColor DarkGreen
az monitor log-analytics workspace create --resource-group $resourceGroupName --workspace-name $logAnalyticsWorkspace -o table

##############################
# Azure Container Registry
##############################

Write-Host "Creating Container Registry: $acrName" -ForegroundColor DarkGreen
az acr create --resource-group "$resourceGroupName" --name $acrName --sku Standard --workspace $logAnalyticsWorkspace --admin-enabled true -o table    

Write-Host "Building with image tags: '$podLabel'" -ForegroundColor DarkGreen
az acr build --image $podLabel --registry $acrName  --file AksBlobDownloader/Dockerfile . --no-logs --query outputimages --no-wait

##############################
# Storage Account
##############################

Write-Host "Creating Storage Account: $storageAccountName" -ForegroundColor DarkGreen
az storage account create --name $storageAccountName --resource-group $resourceGroupName --sku Standard_LRS -o table

Write-Host "Creating Storage Container: $containerName" -ForegroundColor DarkGreen
az storage container create --name $containerName --account-name $storageAccountName --auth-mode login

##############################
# Neworking
##############################

Write-Host "Creating Network Security Group and Port 80 rule for NSG: $nsgName" -ForegroundColor DarkGreen
az network nsg create  --resource-group $resourceGroupName --name $nsgName -o table
az network nsg rule create --resource-group $resourceGroupName --nsg-name $nsgName --name Allow-Port80 --priority 101 --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges "80" --access Allow --protocol "*" --description "Allow Port 80" -o table

Write-Host "Creating Network Security Group $appGwNsg" -ForegroundColor DarkGreen
az network nsg create  --resource-group $resourceGroupName --name $appGwNsg -o table

Write-Host "Creating NSG rule for application gateway and Port 80" -ForegroundColor DarkGreen
az network nsg rule create --resource-group $resourceGroupName --nsg-name $appGwNsg --name Allow-AppGateway --priority 100 --source-address-prefixes GatewayManager --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges "65200-65535" --access Allow --protocol "*" --description "Allow Application Gateway" -o table
az network nsg rule create --resource-group $resourceGroupName --nsg-name $appGwNsg --name Allow-Port80 --priority 101 --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges "80" --access Allow --protocol "*" --description "Allow Port 80" -o table

Write-Host "Creating VNET $aksVnet and AKS subnet: $aksSubnet, for the AKS cluster $aksClusterName" -ForegroundColor DarkGreen
az network vnet create --resource-group $resourceGroupName --name $aksVnet  --address-prefixes 10.180.0.0/20 --subnet-name $aksSubnet --subnet-prefix 10.180.0.0/22  -o table --network-security-group  $nsgName

Write-Host "Retrieving subnet ID value from VNET '$aksVnet' and Subnet '$aksSubnet '"
$aksSubnetId = az network vnet subnet show --resource-group $resourceGroupName --vnet-name $aksVnet --name $aksSubnet --query id -o tsv

Write-Host "Creating App Gateway Subnet: $appGwSubnet, for the AKS cluster $aksClusterName" -ForegroundColor DarkGreen
az network vnet subnet create --resource-group $resourceGroupName --vnet-name $aksVnet --name $appGwSubnet --address-prefixes 10.180.15.0/24  -o table --network-security-group  $appGwNsg

Write-Host "Retrieving subnet ID value from VNET '$aksVnet' and Subnet '$appGwSubnet '"
$appGwSubnetId = az network vnet subnet show --resource-group $resourceGroupName --vnet-name $aksVnet --name $appGwSubnet --query id -o tsv

Write-Host "Creating Public IP '$publicIPName' for App Gateway"
az network public-ip create --resource-group $resourceGroupName --name $publicIPName --allocation-method Static --sku Standard -o table  

########################################################
# AKS Cluster - AppGw will be created by the AKS cluster
########################################################

Write-Host "Creating AKS Cluster: $aksClusterName" -ForegroundColor DarkGreen
az aks create --name $aksClusterName --resource-group $resourceGroupName --node-count 2 --enable-cluster-autoscaler --min-count 2 --max-count 5 --enable-addons azure-policy,monitoring --auto-upgrade-channel patch --network-plugin azure --vnet-subnet-id $aksSubnetId  --generate-ssh-keys --node-osdisk-type Ephemeral --node-vm-size Standard_DS3_v2 -a ingress-appgw --appgw-name $appGatewayName --appgw-subnet-id $appGwSubnetId --attach-acr $acrName --yes -o table

Write-Host "Retrieving credentials for: $aksClusterName to be able to run kubectl commands" -ForegroundColor DarkGreen
az aks get-credentials --name $aksClusterName --resource-group $resourceGroupName --overwrite-existing --admin -o table

###############################
# Create and upload large files
###############################

$rgID = az group show -n $resourceGroupName --query id -o tsv
$userId = az ad signed-in-user show -o tsv --query id
az role assignment create --role "Storage Blob Data Contributor" --assignee $userId --scope $rgID -o table

Write-Host "Creating Large Binary Test Files" -ForegroundColor DarkGreen

Write-host "Creating 1 GB file"
fsutil file createnew onegig.bin 1000000000

Write-host "Creating 1.5 GB file" -ForegroundColor DarkGreen
fsutil file createnew onepointfivegig.bin 1500000000

Write-host "Creating 2 GB file" -ForegroundColor DarkGreen
fsutil file createnew twogig.bin 2000000000

Write-Host "Uploading Files if needed" -ForegroundColor DarkGreen
$blobExists = az storage blob exists --name onegig.bin --container-name $containerName --account-name $storageAccountName --auth-mode login --query exists -o tsv
if($blobExists -eq "false")
{
    az storage blob upload --file onegig.bin --container-name $containerName --account-name $storageAccountName --auth-mode login
}
$blobExists = az storage blob exists --name onegig.bin --container-name $containerName --account-name $storageAccountName --auth-mode login --query exists -o tsv
if($blobExists -eq "false")
{
    az storage blob upload --file onepointfivegig.bin --container-name $containerName --account-name $storageAccountName --auth-mode login
}
az storage blob upload --file onepointfivegig.bin --container-name $containerName --account-name $storageAccountName --auth-mode login

$blobExists = az storage blob exists --name twogig.bin --container-name $containerName --account-name $storageAccountName --auth-mode login --query exists -o tsv
if($blobExists -eq "false")
{
    az storage blob upload --file twogig.bin --container-name $containerName --account-name $storageAccountName --auth-mode login
}


###############################
# Add K8s secrets
###############################
Write-Host "Adding storage secrets to Kubernetes" -ForegroundColor DarkGreen
$storageAccountKey = az storage account keys list -n $storageAccountName --query [0].value -o tsv
kubectl delete secret downloadtest-secret
kubectl create secret generic downloadtest-secret --from-literal="AZURE_STORAGE_KEY=$storageAccountKey" --from-literal="AZURE_STORAGE_ACCOUNT=$storageAccountName" --from-literal="CONTAINER_NAME=$containerName"


#######################################
# Apply deployment, service and ingress
#######################################
Get-Content -Path .\AksBlobDownloader\k8deploy-appgw.yml | % {$_.replace("AZURE_CONTAINER_REGISTRY",$acrName)}  | % {$_.replace("POD_LABEL",$podLabel)} | kubectl apply -f -


#######################################
# Wait For ingress to get IP address
#######################################
$ingressIP = ""

while($ingressIP -eq "" -or $null -eq $ingressIP)
{
    Write-Host "Waiting for ingress to get IP address" -ForegroundColor DarkGreen
    Start-Sleep -Seconds 10
    $ingressIP = kubectl get ingress ingress-appgateway -o=jsonpath='{.status.loadBalancer.ingress[0].ip}'
}

#######################################
# Test the application
#######################################

Write-Host "To test the downloads, use these URLs for the different file sizes" -ForegroundColor DarkGreen


Write-Host "Method that uses ''blobClient.OpenReadAsync()'' for stream downloading" -ForegroundColor Yellow
Write-Host "http://$ingressIP/Home/Download?filename=onegig.bin" -ForegroundColor Cyan
Write-Host "http://$ingressIP/Home/Download?filename=onepointfivegig.bin" -ForegroundColor Cyan
Write-Host "http://$ingressIP/Home/Download?filename=twogig.bin" -ForegroundColor Cyan

Write-Host "Method that uses ''blobClient.DownloadToAsync()'' for stream downloading" -ForegroundColor Yellow
Write-Host "http://$ingressIP/Home/Download2?filename=onegig.bin" -ForegroundColor Cyan
Write-Host "http://$ingressIP/Home/Download2?filename=onepointfivegig.bin" -ForegroundColor Cyan
Write-Host "http://$ingressIP/Home/Download2?filename=twogig.bin" -ForegroundColor Cyan

