param location string = resourceGroup().location

param serverNsgSettings string = 'NSG NAME'

param coreVnetSettings object = {
  name: 'company-vnet-uks-corenetworking'
  addressSpace: '10.60.8.0/24'
  subnets: [
    {
      name: 'gatewaysubnet'
      subnetPrefix: '10.60.8.0/27'
    }
    {
      name: 'bastionsubnet'
      subnetPrefix: '10.60.8.32/27'
    }
    {
      name: 'company-snet-uks-management-servers'
      subnetPrefix: '10.60.8.64/27'
    }
  ]
}

param serverVnetSettings object = {
  name: 'company-vnet-uks-prod-servers'
  addressSpace: '10.60.10.0/24'
  subnets: [
    {
      name: 'company-snet-uks-prod-servers-internal'
      subnetPrefix: '10.60.10.0/25'
    }
    {
      name: 'company-snet-uks-prod-servers-dmz'
      subnetPrefix: '10.60.10.128/25'
    }
  ]
}

param vpnPipSettings object = {
  name: 'company-pip-vgw-uks-core-01'
}

param companyAmsLgwSettings object= {
  name: 'company-lgw-uks-company-ams-office'
  publicIp: '1.2.3.4'
  privateIpRanges: [
    '172.16.36.0/22'
  ]
}

param companyAxsLgwSettings object = {
  name: 'company-lgw-uks-company-axs-office'
  publicIp: '1.2.3.4'
  privateIpRanges: [
    '172.16.4.0/22'
  ]
}

param sysGroupLgwSettings object = {
  name: 'company-lgw-uks-syscloud-manchester'
  publicIp: '1.2.3.4'
  privateIpRanges: [
    '10.50.1.0/24'
  ]
}

param companyAmsVpnConnSettings object = {
  name: 'company-vcon-vgw-uks-core-01-to-lgw-uks-company-ams-office'
  preSharedKey: 'pskpasswordhere'
}

param companyAxsVpnConnSettings object = {
  name: 'company-vcon-vgw-uks-core-01-to-lgw-uks-company-axs-office'
  preSharedKey: 'pskpasswordhere'
}

param sysGroupVpnConnSettings object = {
  name: 'company-vcon-vgw-uks-core-01-to-lgw-uks-syscloud-manchester'
  preSharedKey: 'pskpasswordhere'
}

param vpnGwSettings object = {
  name: 'company-vgw-uks-core-01'
  sku: 'VpnGw1'
}

resource serverNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: serverNsgSettings
  location: location
  properties: {
    securityRules: []
  }
}

resource coreVirtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: coreVnetSettings.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        coreVnetSettings.addressSpace
      ]
    }
  }
}

@batchSize(1)
resource coreSubnets 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = [for (sn, index) in coreVnetSettings.subnets: {
  name: sn.name
  parent: coreVirtualNetwork
  properties: {
    addressPrefix: sn.subnetPrefix
  }
}]

resource serverVirtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: serverVnetSettings.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        serverVnetSettings.addressSpace
      ]
    }
  }
}

@batchSize(1)
resource serverSubnets 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = [for (sn, index) in serverVnetSettings.subnets: {
  name: sn.name
  parent: serverVirtualNetwork
  properties: {
    addressPrefix: sn.subnetPrefix
    networkSecurityGroup: {
      id: serverNetworkSecurityGroup.id
    }
  }
}]

resource serverToCorePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-07-01' = {
  parent: serverVirtualNetwork
  dependsOn: [
    virtualNetworkGateway
  ]
  name: 'peer-${serverVirtualNetwork.name}-to-${coreVirtualNetwork.name}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: true
    remoteVirtualNetwork: {
      id: coreVirtualNetwork.id
    }
  }
}

resource coreToServerPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-07-01' = {
  parent: coreVirtualNetwork
  dependsOn: [
    virtualNetworkGateway
  ]
  name: 'peer-${coreVirtualNetwork.name}-to-${serverVirtualNetwork.name}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: serverVirtualNetwork.id
    }
  }
}

resource vpnPip 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: vpnPipSettings.name
  location: resourceGroup().location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: vpnPipSettings.name
    }
  }
}

resource virtualNetworkGateway 'Microsoft.Network/virtualNetworkGateways@2020-11-01' = {
  name: vpnGwSettings.name
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', coreVnetSettings.name, coreVnetSettings.subnets[0].name)
          }
          publicIPAddress: {
            id: vpnPip.id
          }
        }
      }
    ]
    sku: {
      name: vpnGwSettings.sku
      tier: vpnGwSettings.sku
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: true
  }
}

resource sysGroupLng 'Microsoft.Network/localNetworkGateways@2019-11-01' = {
  name: sysGroupLgwSettings.name
  location: resourceGroup().location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: sysGroupLgwSettings.privateIpRanges
    }
    gatewayIpAddress: sysGroupLgwSettings.publicIp
  }
}

resource companyAmsLng 'Microsoft.Network/localNetworkGateways@2019-11-01' = {
  name: companyAmsLgwSettings.name
  location: resourceGroup().location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: companyAmsLgwSettings.privateIpRanges
    }
    gatewayIpAddress: companyAmsLgwSettings.publicIp
  }
}

resource companyAxsLng 'Microsoft.Network/localNetworkGateways@2019-11-01' = {
  name: companyAxsLgwSettings.name
  location: resourceGroup().location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: companyAxsLgwSettings.privateIpRanges
    }
    gatewayIpAddress: companyAxsLgwSettings.publicIp
  }
}

resource sysGroupVpnConn 'Microsoft.Network/connections@2020-11-01' = {
  name: sysGroupVpnConnSettings.name
  location: resourceGroup().location
  properties: {
    virtualNetworkGateway1: {
      id: virtualNetworkGateway.id
      properties: {}
    }
    localNetworkGateway2: {
      id: sysGroupLng.id
      properties: {}
    }
    connectionType: 'IPsec'
    routingWeight: 0
    sharedKey: sysGroupVpnConnSettings.preSharedKey
  }
}

resource companyAmsVpnConn 'Microsoft.Network/connections@2020-11-01' = {
  name: companyAmsVpnConnSettings.name
  location: resourceGroup().location
  properties: {
    virtualNetworkGateway1: {
      id: virtualNetworkGateway.id
      properties: {}
    }
    localNetworkGateway2: {
      id: companyAmsLng.id
      properties: {}
    }
    connectionType: 'IPsec'
    routingWeight: 0
    sharedKey: companyAmsVpnConnSettings.preSharedKey
  }
}

resource companyAxsVpnConn 'Microsoft.Network/connections@2020-11-01' = {
  name: companyAxsVpnConnSettings.name
  location: resourceGroup().location
  properties: {
    virtualNetworkGateway1: {
      id: virtualNetworkGateway.id
      properties: {}
    }
    localNetworkGateway2: {
      id: companyAxsLng.id
      properties: {}
    }
    connectionType: 'IPsec'
    routingWeight: 0
    sharedKey: companyAxsVpnConnSettings.preSharedKey
  }
}
