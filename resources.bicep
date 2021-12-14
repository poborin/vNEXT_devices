param MY_PARAM int

var location = resourceGroup().location
var suffix = 'code-exercise'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: 'podevicescodeexercise'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource devicesTableServices 'Microsoft.Storage/storageAccounts/tableServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
}

resource devicesTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2021-06-01' = {
  name: 'devicesTable'
  parent: devicesTableServices
}

resource devicesQueueServices 'Microsoft.Storage/storageAccounts/queueServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
}

resource devicesQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2021-06-01' = {
  name: 'devices-queue'
  parent: devicesQueueServices
  properties: {
    metadata: {}
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: 'service-plan-${suffix}'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

resource injestDevicesApp 'Microsoft.Web/sites@2021-02-01' = {
  name: 'injest-payload-${suffix}'
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {

    }
  }
  dependsOn: [
    appServicePlan
  ]
}

var mainSiteAppSettings = {
  FUNCTIONS_WORKER_RUNTIME: 'dotnet'
  FUNCTIONS_EXTENSION_VERSION: '~3'
  WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
  WEBSITE_CONTENTSHARE: '${substring(uniqueString(resourceGroup().id), 3)}-${suffix}'
  AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value};EndpointSuffix=core.windows.net'
}

resource mainSiteConfigSettings 'Microsoft.Web/sites/config@2021-02-01' = {
  parent: injestDevicesApp
  name: 'appsettings'
  properties: mainSiteAppSettings
  dependsOn: [
    storageAccount
  ]
}
