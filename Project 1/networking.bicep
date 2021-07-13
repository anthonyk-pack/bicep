param location string = resourceGroup().location

param serverNsgSettings string = 'NSG NAME'

param coreVnetSettings object = {
  name: 'companya-vnet-uks-corenetworking'
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
      name: 'companya-snet-uks-management-servers'
      subnetPrefix: '10.60.8.64/27'
    }
  ]
}

param serverVnetSettings object = {
  name: 'companya-vnet-uks-prod-servers'
  addressSpace: '10.60.10.0/24'
  subnets: [
    {
      name: 'companya-snet-uks-prod-servers-internal'
      subnetPrefix: '10.60.10.0/25'
    }
    {
      name: 'companya-snet-uks-prod-servers-dmz'
      subnetPrefix: '10.60.10.128/25'
    }
  ]
}

param vpnPipSettings object = {
  name: 'companya-pip-vgw-uks-core-01'
}

param companyaAmsLgwSettings object= {
  name: 'companya-lgw-uks-companya-ams-office'
  publicIp: '1.2.3.4'
  privateIpRanges: [
    '172.16.36.0/22'
  ]
}

param companyaAxsLgwSettings object = {
  name: 'companya-lgw-uks-companya-axs-office'
  publicIp: '1.2.3.4'
  privateIpRanges: [
    '172.16.4.0/22'
  ]
}

param sysGroupLgwSettings object = {
  name: 'companya-lgw-uks-syscloud-manchester'
  publicIp: '1.2.3.4'
  privateIpRanges: [
    '10.50.1.0/24'
  ]
}

param companyaAmsVpnConnSettings object = {
  name: 'companya-vcon-vgw-uks-core-01-to-lgw-uks-companya-ams-office'
  preSharedKey: 'pskpasswordhere'
}

param companyaAxsVpnConnSettings object = {
  name: 'companya-vcon-vgw-uks-core-01-to-lgw-uks-companya-axs-office'
  preSharedKey: 'pskpasswordhere'
}

param sysGroupVpnConnSettings object = {
  name: 'companya-vcon-vgw-uks-core-01-to-lgw-uks-syscloud-manchester'
  preSharedKey: 'pskpasswordhere'
}

param vpnGwSettings object = {
  name: 'companya-vgw-uks-core-01'
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

resource companyaAmsLng 'Microsoft.Network/localNetworkGateways@2019-11-01' = {
  name: companyaAmsLgwSettings.name
  location: resourceGroup().location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: companyaAmsLgwSettings.privateIpRanges
    }
    gatewayIpAddress: companyaAmsLgwSettings.publicIp
  }
}

resource companyaAxsLng 'Microsoft.Network/localNetworkGateways@2019-11-01' = {
  name: companyaAxsLgwSettings.name
  location: resourceGroup().location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: companyaAxsLgwSettings.privateIpRanges
    }
    gatewayIpAddress: companyaAxsLgwSettings.publicIp
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

resource companyaAmsVpnConn 'Microsoft.Network/connections@2020-11-01' = {
  name: companyaAmsVpnConnSettings.name
  location: resourceGroup().location
  properties: {
    virtualNetworkGateway1: {
      id: virtualNetworkGateway.id
      properties: {}
    }
    localNetworkGateway2: {
      id: companyaAmsLng.id
      properties: {}
    }
    connectionType: 'IPsec'
    routingWeight: 0
    sharedKey: companyaAmsVpnConnSettings.preSharedKey
  }
}

resource companyaAxsVpnConn 'Microsoft.Network/connections@2020-11-01' = {
  name: companyaAxsVpnConnSettings.name
  location: resourceGroup().location
  properties: {
    virtualNetworkGateway1: {
      id: virtualNetworkGateway.id
      properties: {}
    }
    localNetworkGateway2: {
      id: companyaAxsLng.id
      properties: {}
    }
    connectionType: 'IPsec'
    routingWeight: 0
    sharedKey: companyaAxsVpnConnSettings.preSharedKey
  }
}
