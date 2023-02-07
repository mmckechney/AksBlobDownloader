# Demo Container and Process to download large files from AKS

This sample app uses a simple .NET 7 ASP.NET MVC app, deployed as a container in Azure Kubernetes Service to demonstrate and test downloading very large files (1 GB+) from Azure Storage.

## Get started

To deploy this solution, you will need contributor access to an Azure Subscription or Resource Group. You will also need to have the [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed.

Deployment:

``` powershell
az login

.\deploy.ps1 -prefix <4-8 character prefix>

```

## The Details
This script will create all of the Azure resources you need to run the test:

- Storage Account
- Azure Container Registry (including uploading and building the image)
- Log Analytics Workspace
- Virtual Network and needed subnets
- Application Gateway (for ingress)
- Azure Public IP for Application Gateway
- Azure Kubernetes Service Cluster with 2 Linux nodes

It will then:

- Create 3 large files: 1, 1.5 and 2 GB and upload them to the storage account
- Create a Kubernetes secret for the storage account, storage container name and  key
- Deploy the Kubernetes resources:
  - Deployment of 2 containers
  - A service hosting the deployment
  - An ingress for the service

Once the ingress is assigned an external IP, the commandline output will display 3 URLs you can use to test downloading each file

### The 'Download' method uses "blobClient.OpenReadAsync()" for stream downloading

```
# Using curl to download the files with optional rate limiting
http://<ip address>/Home/Download?filename=onegig.bin
http://<ip address>/Home/Download?filename=onepointfivegig.bin
http://<ip address>/Home/Download?filename=twogig.bin
 
# Using curl to download the files with optional rate limiting
curl http://<ip address>/Home/Download?filename=onegig.bin --output onegig.bin --limit-rate 200K
curl http://<ip address>/Home/Download?filename=onepointfivegig.bin --output onepointfivegig.bin --limit-rate 200K
curl http://<ip address>/Home/Download?filename=twogig.bin --output twogig.bin --limit-rate 200K
```

### The 'Download2' method uses  blobClient.DownloadStreaming() with BlobDownloadStreamingResult for stream downloading

```
# Using curl to download the files with optional rate limiting
http://<ip address>/Home/Download2?filename=onegig.bin
http://<ip address>/Home/Download2?filename=onepointfivegig.bin
http://<ip address>/Home/Download2?filename=twogig.bin
 
# Using curl to download the files with optional rate limiting
curl http://<ip address>/Home/Download2?filename=onegig.bin --output onegig.bin --limit-rate 200K
curl http://<ip address>/Home/Download2?filename=onepointfivegig.bin --output onepointfivegig.bin --limit-rate 200K
curl http://<ip address>/Home/Download2?filename=twogig.bin --output twogig.bin --limit-rate 200K
```