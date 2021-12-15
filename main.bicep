targetScope = 'subscription'

resource devicesResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-devices'
  location: 'australiasoutheast'
}

module myModule 'resources.bicep' = {
  scope: devicesResourceGroup
  name: 'myModule'
}
