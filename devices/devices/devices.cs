using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Queue;
using Newtonsoft.Json;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using System.Net.Http;
using System;
using Microsoft.WindowsAzure.Storage.Table;

namespace devices
{
    public class Device
    {
        public string id { get; set; }
        public string Name { get; set; }
        public string location { get; set; }
        public string type { get; set; }
    }

    public class Payload
    {
        public string correlationId { get; set; }
        public List<Device> devices { get; set; }
    }

    public class DeviceIdWithAssetId
    {
        public string deviceId { get; set; }
        public string assetId { get; set; }
    }

    public class DeviceEntity : TableEntity
    {
        public string deviceId { get; set; }
        public string Name { get; set; }
        public string Location { get; set; }
        public string Type { get; set; }
        public string AssetId { get; set; }

        public DeviceEntity(Device device, string assetId)
        {
            this.PartitionKey = device.id;
            this.RowKey = assetId;
            this.deviceId = device.id;
            this.Name = device.Name;
            this.Location = device.location;
            this.Type = device.type;
            this.AssetId = assetId;
        }
    }

    public static class Devices
    {
        [FunctionName("parseDevices")]
        public static async Task Run(
            [HttpTrigger(AuthorizationLevel.Function, "post", Route = null)] HttpRequest req,
            ILogger log)
        {
            log.LogInformation("C# HTTP trigger function processed a request.");

            string body = await req.ReadAsStringAsync();
            var payload = JsonConvert.DeserializeObject<Payload>(body);
            var devices = payload.devices.ChunkBy(100);

            var config = new ConfigurationBuilder()
                            .AddEnvironmentVariables()
                            .Build();
            var storageConnectionString = config["AzureWebJobsStorage"];
            CloudStorageAccount storageAccount = CloudStorageAccount.Parse(storageConnectionString);
            CloudQueueClient queueClient = storageAccount.CreateCloudQueueClient();
            CloudQueue queue = queueClient.GetQueueReference("devices-queue"); // TODO: get the queue name

            devices
                .ConvertAll(x =>
                {
                    var p = JsonConvert.SerializeObject(x);
                    return new CloudQueueMessage(p);
                })
                .ForEach(async x => await queue.AddMessageAsync(x));
        }

        [FunctionName("setDevices")]
        public static async Task Run([QueueTrigger("devices-queue", Connection = "AzureWebJobsStorage")] string myQueueItem, ILogger log)
        {
            var devices = JsonConvert.DeserializeObject<List<Device>>(myQueueItem);
            var deviceIds = devices.Select(d => d.id);
            var p = JsonConvert.SerializeObject(deviceIds);

            string body = "";
            using (var client = new HttpClient())
            {
                client.BaseAddress = new Uri("http://tech-assessment.vnext.com.au");
                client.DefaultRequestHeaders.Add("x-functions-key", "DRefJc8eEDyJzS19qYAKopSyWW8ijoJe8zcFhH5J1lhFtChC56ZOKQ==");
                var result = await client.PostAsJsonAsync("/api/devices/assetId/", deviceIds);

                if (!result.IsSuccessStatusCode)
                {
                    throw new Exception("Could not retrieve devices asset aids");
                }

                body = await result.Content.ReadAsStringAsync();
            }
            var devicesWithAssetIds = JsonConvert.DeserializeObject<List<DeviceIdWithAssetId>>(body);

            var config = new ConfigurationBuilder()
                            .AddEnvironmentVariables()
                            .Build();
            var storageConnectionString = config["AzureWebJobsStorage"];
            CloudStorageAccount storageAccount = CloudStorageAccount.Parse(storageConnectionString);
            var tableClient = storageAccount.CreateCloudTableClient();
            var devicesTable = tableClient.GetTableReference("devicesTable");

            var batchOperation = new TableBatchOperation();
            devices
                .ConvertAll(d =>
                {
                    var da = devicesWithAssetIds.Find(x => x.deviceId == d.id);
                    return new DeviceEntity(d, da.assetId);
                })
                .ForEach(e => batchOperation.InsertOrReplace(e));
            await devicesTable.ExecuteBatchAsync(batchOperation);
        }
    }
}

/// <summary>
/// Helper methods for the lists.
/// </summary>
public static class ListExtensions
{
    public static List<List<T>> ChunkBy<T>(this List<T> source, int chunkSize)
    {
        return source
            .Select((x, i) => new { Index = i, Value = x })
            .GroupBy(x => x.Index / chunkSize)
            .Select(x => x.Select(v => v.Value).ToList())
            .ToList();
    }
}