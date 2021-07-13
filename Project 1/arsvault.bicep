param location string = resourceGroup().location
param backupPolicyRG string = 'tjm-rg-uks-azbackup-prod-server-recoverypoints-'
var vaultName = 'tjm-rsv-uks-production-01' 

resource recoveryServiceVault 'Microsoft.RecoveryServices/vaults@2021-01-01' = {
  name: vaultName
  location: location
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {}
}

resource vaultName_vaultstorageconfig 'Microsoft.RecoveryServices/vaults/backupstorageconfig@2018-12-20' = {
  dependsOn: [
    recoveryServiceVault
  ]
  name: '${vaultName}/vaultstorageconfig'
  properties: {
    storageModelType: 'GeoRedundant'
    crossRegionRestoreFlag: true
  }
}

resource vaultName_standard_backup 'Microsoft.RecoveryServices/vaults/backupPolicies@2019-06-15' = {
  dependsOn: [
    recoveryServiceVault
  ]
  name: '${vaultName}/production-vms'
  location: location
  properties: {
    backupManagementType: 'AzureIaasVM'
    instantRPDetails: {
      azureBackupRGNamePrefix: backupPolicyRG
    }
    instantRpRetentionRangeInDays: 2
    schedulePolicy: {
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: [
        '20:00'
      ]
      schedulePolicyType: 'SimpleSchedulePolicy'
    }
    retentionPolicy: {
      dailySchedule: {
        retentionTimes: [
          '20:00'
        ]
    retentionDuration: {
        count: 7
        durationType: 'Days'
      }
    }
    weeklySchedule: {
      daysOfTheWeek: [
        'Sunday'
      ]
      retentionTimes: [
        '20:00'
      ]
      retentionDuration: {
        count: 4
        durationType: 'Weeks'
      }
    }
    retentionPolicyType: 'LongTermRetentionPolicy'
    }
    timeZone: 'GMT Standard Time'
  }
}

