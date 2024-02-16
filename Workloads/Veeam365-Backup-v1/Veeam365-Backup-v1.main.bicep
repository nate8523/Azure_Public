/*
####################################################################################################
# Script Name: Veeam365-Backup-v1.main.bicep
# Description: Deploys Veeam365 into Azure
# Version: 1.0
# Author: Nathan Carroll
# Date: 27 Jul 2023
# Modified Date: 27 Jul 2023
# Change Log:
#   - Version 1.0: Initial version. 
####################################################################################################
*/
// ######## Parameters ########

@description('Azure Region for the deployment')
param location string = resourceGroup().location

@description('deployment environment')
@allowed([
  'PROD'
  'DEV'
  'TEST'
  'DEMO'
])
param environment string

@description('Indicates whether to create a new VNet or use an existing one')
@allowed([
  'new'
  'existing'
])
param vnetDeploymentOption string

@description('Name of the existing VNet (required if using an existing VNet)')
param existingVnetResourceGroupName string

@description('Name of the existing VNet (required if using an existing VNet)')
param existingVnetName string

@description('Name of the existing subnet (required if using an existing VNet)')
param existingSubnetName string

@description(' Tags will be added to all resources deployed')
var tagValues = {
  Environment: environment
}

@description('two digit number to append to all resources for naming convention')
param index int
var index2 = (index < 10) ? '0${index}' : '${index}'

@description('Name of the project.  used in naming convention')
param projectPrefix string

@description('')
var nsgName = '${environment}-NSG-${projectPrefix}-${index2}'

@description('Name and IP address range of the Virtual Network')
var vnetName = '${environment}-VNET-${projectPrefix}-${index2}'
param vnetAddress string

@description('Name and IP address range of Subnet 1')
var snetName = '${environment}-SNET-${projectPrefix}-${index2}'
param snet1Address string

@description('IP Allocation Method for Public IP')
param PublicIPallocation string

@description('Name and IP address range of Public IP assigned yo Veeam VM')
var pipName = '${environment}-PIP-EXT-${projectPrefix}-${index2}'
param PublicIPsku string

@description('')
var vmNicName = '${environment}-NIC-${projectPrefix}-${index2}'

@description('')
var vmName = '${environment}-VM-${projectPrefix}-${index2}'

@description('Size of the Veeam VM')
@allowed([
  'Standard_B1ms'
  'Standard_B2s'
  'Standard_D4S_v4'
  'Standard_D8s_v5'
])
param vmSize string

@description(' Configuration detials of the VM Diagnostics storage account')
var vmDiagStoreName = '${environment}STR${projectPrefix}${index2}'
param vmDiagStoreKind string = 'Storage'
param vmDiagStoreSKU string = 'Standard_LRS'

@description('')
var osDiskName = '${vmName}-OSDisk'

@description('')
param osDiskType string

@description('Configuration of the Veeam Image Version')
param imagePublisher string
param imageOffer string
param imageSKU string
param imageVersion string

@description('Name and Disk type for Veeam backup disk')
var dataDiskName = '${vmName}-DataDisk'
param dataDiskType string
param dataDiskSize int

@description('Computer Name and Credentials of the local admin account')
param computerName string
param adminUsername string
@secure()
param adminPassword string

@description('Script to mount and attach veeam storage accounts')
param scriptURL string = 'https://raw.githubusercontent.com/nate8523/Azure_Public/main/Workloads/Veeam365-Backup-v1/Customisation/Customise-VeeamBR-v1.ps1'


// ######## Resources ########

@description('Creates a Network Security Group to allow Veeam Cloud Connect Ports')
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  tags: tagValues
  properties: {
    securityRules: [
      {
        name: 'CloudConnect-TCP'
        properties: {
          protocol: 'Tcp'
          priority: 1010
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '6180'
      }
    }
    {
      name: 'CloudConnect-UDP'
      properties: {
        protocol: 'UDP'
        priority: 1011
        access: 'Allow'
        direction: 'Inbound'
        sourceAddressPrefix: '*'
        sourcePortRange: '*'
        destinationAddressPrefix: '*'
        destinationPortRange: '6180'
    }
  }
  {
    name: 'Allow-Inbound-RDP'
    properties: {
      protocol: 'Tcp'
      priority: 1012
      access: 'Allow'
      direction: 'Inbound'
      sourceAddressPrefix: '*'
      sourcePortRange: '*'
      destinationAddressPrefix: '*'
      destinationPortRange: '3389'
  }
}
    ]
  }
}

@description('Create a virtual network for the Veeam VM')
resource virtualNetworkName 'Microsoft.Network/virtualNetworks@2023-04-01' = if (vnetDeploymentOption == 'new') {
  name: vnetName
  location: location
  tags: tagValues
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddress
      ]
    }
    subnets: [
      {
        name: snetName
        properties: {
          addressPrefix: snet1Address
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

resource publicIpAddressName 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: pipName
  location: location
  tags: tagValues
  properties: {
    publicIPAllocationMethod: PublicIPallocation
    }
    sku: {
      name: PublicIPsku
  }
}

resource networkInterfaceName 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: vmNicName
  location: location
  tags: tagValues
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: (vnetDeploymentOption == 'new') ? '${virtualNetworkName.id}/subnets/${snetName}' : resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', existingVnetName, existingSubnetName)
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpAddressName.id
          }
        }      
      }
    ]
  }
}

resource vmDiagStorage 'Microsoft.Storage/storageAccounts@2023-01-01' ={
  name: toLower(vmDiagStoreName)
  location: location
  tags: tagValues
  kind: vmDiagStoreKind
  sku: {
    name: vmDiagStoreSKU
  }
}

resource virtualmachine 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  tags: tagValues
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        name: osDiskName
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSKU
        version: imageVersion
      }
      dataDisks: [
        {
          diskSizeGB: dataDiskSize
          lun: 0
          createOption: 'Empty'
          name: dataDiskName
          managedDisk: {
            storageAccountType: dataDiskType
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceName.id
          properties: {
          }
        }
      ]
    }
    osProfile: {
      computerName: computerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          enableHotpatching: false
          patchMode: 'AutomaticByOS'
        }
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: vmDiagStorage.properties.primaryEndpoints.blob
      }
    }
  }
  plan: {
    name: imageSKU
    publisher: imagePublisher
    product: imageOffer
  }
}

resource customscriptextension 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  parent: virtualmachine
  name: 'VeeamDataDisk'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        scriptURL
      ]
      commandToExecute: 'powershell -ExecutionPolicy Bypass -File Customise-VeeamBR-v1.ps1'
    }
}
}
