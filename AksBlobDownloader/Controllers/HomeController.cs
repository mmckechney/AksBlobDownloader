using AksBlobDownloader.Models;
using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;
using Azure.Storage.Blobs;
using Azure.Storage;

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
    }
}