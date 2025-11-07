using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using System;
using System.Net.Http;
using System.Text;

namespace HackThePlatform.Plugins
{
    public class CreateBlobFolderRestPlugin : IPlugin
    {
        private readonly string _unsecureConfig;
        private readonly string _secureConfig;

        public CreateBlobFolderRestPlugin(string unsecureConfig, string secureConfig)
        {
            _unsecureConfig = unsecureConfig;
            _secureConfig = secureConfig;
        }

        public void Execute(IServiceProvider serviceProvider)
        {
            var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
            var tracing = (ITracingService)serviceProvider.GetService(typeof(ITracingService));
            var factory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
            var service = factory.CreateOrganizationService(context.UserId);

            try
            {
                if (!context.MessageName.Equals("Create", StringComparison.OrdinalIgnoreCase))
                    return;

                if (!context.OutputParameters.Contains("id"))
                    throw new InvalidPluginExecutionException("No record ID found in context.");

                Guid recordId = (Guid)context.OutputParameters["id"];
                tracing.Trace($"Record ID: {recordId}");

                string storageAccount = null;
                string containerName = null;

                if (!string.IsNullOrWhiteSpace(_unsecureConfig))
                {
                    var parts = _unsecureConfig.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries);
                    foreach (var p in parts)
                    {
                        int idx = p.IndexOf('=');
                        if (idx <= -1) continue;
                        var key = p.Substring(0, idx).Trim();
                        var val = p.Substring(idx + 1).Trim();

                        if (key.Equals("Account", StringComparison.OrdinalIgnoreCase) ||
                            key.Equals("StorageAccount", StringComparison.OrdinalIgnoreCase))
                            storageAccount = val;
                        else if (key.Equals("Container", StringComparison.OrdinalIgnoreCase))
                            containerName = val;
                    }
                }

                if (string.IsNullOrWhiteSpace(storageAccount))
                    throw new InvalidPluginExecutionException("Storage account name missing in unsecure configuration.");
                if (string.IsNullOrWhiteSpace(containerName))
                    throw new InvalidPluginExecutionException("Container name missing in unsecure configuration.");

                string sasToken = _secureConfig?.TrimStart('?');
                if (string.IsNullOrWhiteSpace(sasToken))
                    throw new InvalidPluginExecutionException("Secure configuration (SAS token) missing.");

                string folderName = recordId.ToString();
                string blobName = $"{folderName}/.keep";

                string blobUrl = $"https://{storageAccount}.blob.core.windows.net/{containerName}/{blobName}?{sasToken}";
                tracing.Trace($"Creating blob at URL: {blobUrl}");

                using (var http = new HttpClient())
                {
                    http.DefaultRequestHeaders.Add("x-ms-blob-type", "BlockBlob");
                    http.DefaultRequestHeaders.Add("x-ms-version", "2023-11-03");

                    var response = http.PutAsync(blobUrl, new StringContent(string.Empty, Encoding.UTF8, "text/plain")).Result;
                    if (!response.IsSuccessStatusCode)
                    {
                        string msg = $"Azure Blob creation failed: {(int)response.StatusCode} {response.ReasonPhrase}";
                        tracing.Trace(msg);
                        throw new InvalidPluginExecutionException(msg);
                    }
                }

                string folderUrl = $"https://{storageAccount}.blob.core.windows.net/{containerName}/{folderName}/";
                var update = new Entity(context.PrimaryEntityName, recordId)
                {
                    ["crad2_folderurl"] = folderUrl
                };

                service.Update(update);
                tracing.Trace($"Folder created and FolderUrl updated to: {folderUrl}");
            }
            catch (Exception ex)
            {
                tracing.Trace("Exception in CreateBlobFolderRestPlugin: " + ex);
                throw new InvalidPluginExecutionException("Error in plugin: " + ex.Message, ex);
            }
        }
    }

}
