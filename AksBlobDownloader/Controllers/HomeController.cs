using AksBlobDownloader.Models;
using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;
using Azure.Storage.Blobs;
using Azure.Storage;
using Azure.Storage.Blobs.Models;
using Azure;
using Microsoft.AspNetCore.Authorization;

namespace AksBlobDownloader.Controllers
{
    public class HomeController : Controller
    {
        private readonly ILogger<HomeController> _logger;

        public HomeController(ILogger<HomeController> logger)
        {
            _logger = logger;
        }

        public IActionResult Index()
        {
            return View();
        }

        public IActionResult Privacy()
        {
            return View();
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }

        public async Task<IActionResult> Download(string filename)
        {

            var accountName = Environment.GetEnvironmentVariable("AZURE_STORAGE_ACCOUNT");
            var storageKey = Environment.GetEnvironmentVariable("AZURE_STORAGE_KEY");
            var storageContainerName = Environment.GetEnvironmentVariable("CONTAINER_NAME");
            Uri blobContainerUri = new(string.Format("https://{0}.blob.core.windows.net/{1}", accountName, storageContainerName));

            StorageSharedKeyCredential storageSharedKeyCredential = new(accountName, storageKey);

            BlobContainerClient blobContainerClient = new(blobContainerUri, storageSharedKeyCredential);
            var blobClient = blobContainerClient.GetBlobClient(filename);
            var stream = await blobClient.OpenReadAsync();
            return File(stream, "text/plain", filename);

        }

        [HttpGet]
        public IActionResult Download2(string filename)
        {
            try
            {
                try
                {
                    var blobDownloadInfo = DownloadFile2(filename);
                    return File(blobDownloadInfo.Content, blobDownloadInfo.Details.ContentType, filename);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in BlobDownLoadFile");
                    _logger.LogInformation("Error in BlobDownLoadFile: " + ex?.Message?.ToString());
                    _logger.LogInformation("Error in BlobDownLoadFile: " + ex?.InnerException?.Message?.ToString());
                    throw;
                }
            }
            catch (RequestFailedException ex)
            {
                return Problem(ex.ToString());
            }
            catch (Exception ex)
            {
                return Problem(ex.StackTrace, string.Empty, null, ex.Message, "Exception");
            }
        }

        public BlobDownloadStreamingResult DownloadFile2(string filename)
        {
            var accountName = Environment.GetEnvironmentVariable("AZURE_STORAGE_ACCOUNT");
            var storageKey = Environment.GetEnvironmentVariable("AZURE_STORAGE_KEY");
            var storageContainerName = Environment.GetEnvironmentVariable("CONTAINER_NAME");

            var connectionStringLegacyStand = $"DefaultEndpointsProtocol=https;AccountName={accountName};AccountKey={storageKey};EndpointSuffix=core.windows.net";
             BlobClient blobClient = new BlobClient(connectionStringLegacyStand, storageContainerName, filename);
            _logger.LogInformation(DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss.ff") + " DownloadFile2 method: DownloadStreaming started");
            BlobDownloadStreamingResult blobDownloadInfo = blobClient.DownloadStreaming();
            _logger.LogInformation(DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss.ff") + " DownloadFile2 method: DownloadStreaming ended");
            return blobDownloadInfo;
        }

        
    }
}