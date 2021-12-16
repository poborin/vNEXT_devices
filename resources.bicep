var location = resourceGroup().location
var suffix = 'code-exercise'

var storageAccountName = 'podevicescodeexercise'
var devicesTableName = 'devicesTable'
var devicesQueueName = 'devices-queue'
var appServicePlanName = 'service-plan-${suffix}'
var functionAppName = 'injest-payload-${suffix}'
var appInsightsName = 'app-insights-${suffix}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
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
  name: devicesTableName
  parent: devicesTableServices
}

resource devicesQueueServices 'Microsoft.Storage/storageAccounts/queueServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
}

resource devicesQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2021-06-01' = {
  name: devicesQueueName
  parent: devicesQueueServices
  properties: {
    metadata: {}
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

resource injestDevicesApp 'Microsoft.Web/sites@2021-02-01' = {
  name: functionAppName
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
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: { 
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: {
    // circular dependency means we can't reference functionApp directly  /subscriptions/<subscriptionId>/resourceGroups/<rg-name>/providers/Microsoft.Web/sites/<appName>"
     'hidden-link:/subscriptions/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/sites/${functionAppName}': 'Resource'
  }
}

var mainSiteAppSettings = {
  APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.properties.InstrumentationKey
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
}
