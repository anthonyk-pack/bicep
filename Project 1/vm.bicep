param duoadminUserName string = 'duoadmin'
param adminUserName string = 'companyadmin'

@secure()
param duoadminPassword string
@secure()
param adminPassword string

param duoVmName string = 'company-vm-uks-duo01'
param duoHostOSName string = 'company-uks-duo01'
param duoVmSize string = 'Standard_B2s'
param dcVmName string = 'company-vm-uks-dc01'
param dcHostOSName string = 'company-uks-dc01'
param dcVmSize string = 'Standard_B2s'
param excVmName string = 'company-vm-uks-exc'
param excHostOSName string = 'company-uks-exc'
param excVmSize string = 'Standard_D4ds_v4'
param OSVersion string = '2019-Datacenter'
param location string = resourceGroup().location
param subscriptionId string = subscription().id
param coreNetworkRg string = 'company-rg-uks-coreservices'
param dmzSubnet string = 'company-snet-uks-prod-servers-dmz'
param internalSubnet string = 'company-snet-uks-prod-servers-internal' 
param vNet string = 'company-vnet-uks-prod-servers'

var nicConfig = 'ipconfig1'

resource duoNic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${duoVmName}-nic1'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: nicConfig
        properties: {
          privateIPAddress: '10.60.10.138'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: '${subscriptionId}/resourceGroups/${coreNetworkRg}/providers/Microsoft.Network/virtualNetworks/${vNet}/subnets/${dmzSubnet}'
          }
        }
      }
    ]
  }
}

resource dcNic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${dcVmName}-nic1'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: nicConfig
        properties: {
          privateIPAddress: '10.60.10.10'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: '${subscriptionId}/resourceGroups/${coreNetworkRg}/providers/Microsoft.Network/virtualNetworks/${vNet}/subnets/${internalSubnet}'
          }
        }
      }
    ]
  }
}

resource excNic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${excVmName}-nic1'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: nicConfig
        properties: {
          privateIPAddress: '10.60.10.11'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: '${subscriptionId}/resourceGroups/${coreNetworkRg}/providers/Microsoft.Network/virtualNetworks/${vNet}/subnets/${internalSubnet}'
          }
        }
      }
    ]
  }
}

resource dcDataDisk 'Microsoft.Compute/disks@2020-12-01' = {
  name: '${dcVmName}-disk01'
  location: location
  sku: {
    name: 'StandardSSD_LRS'
  }
  properties: {
    diskSizeGB: 64
    creationData: {
      createOption: 'Empty'
    }
  }
}

resource excDataDisk 'Microsoft.Compute/disks@2020-12-01' = {
  name: '${excVmName}-disk01'
  location: location
  sku: {
    name: 'StandardSSD_LRS'
  }
  properties: {
    diskSizeGB: 256
    creationData: {
      createOption: 'Empty'
    }
  }
}

resource duoVM 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: duoVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: duoVmSize
    }
    osProfile: {
      computerName: duoHostOSName
      adminUsername: duoadminUserName
      adminPassword: duoadminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: OSVersion
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: duoNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }


}

resource dcVM 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: dcVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: dcVmSize
    }
    osProfile: {
      computerName: dcHostOSName
      adminUsername: adminUserName
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: OSVersion
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
      dataDisks: [
        {
          name: '${dcVmName}-disk01'
          caching: 'None'
          lun: 0
          createOption: 'Attach'
          managedDisk: {
            id: dcDataDisk.id
          }
        }
      ]   
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: dcNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource excVM 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: excVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: excVmSize
    }
    osProfile: {
      computerName: excHostOSName
      adminUsername: adminUserName
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: OSVersion
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
      dataDisks: [
        {
          name: '${excVmName}-disk01'
          caching: 'ReadOnly'
          lun: 0
          createOption: 'Attach'
          managedDisk: {
            id: excDataDisk.id
          }
        }
      ]   
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: excNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

output subscriptionId string = subscriptionId 
