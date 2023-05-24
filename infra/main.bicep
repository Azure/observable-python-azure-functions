var suffix = uniqueString(resourceGroup().id)

var appName  = 'functionapp-${suffix}'

@description('Storage Account type')
@allowed([
  'Standard_LRS'
])
param storageAccountType string = 'Standard_LRS'

@description('Location for all resources.')
param location string = resourceGroup().location


@description('The name for the database')
param databaseName string = 'ContosoDatabase'


@description('Specifies the messaging tier for Event Hub Namespace.')
@allowed([
  'Basic'
  'Standard'
])
param eventHubSku string = 'Standard'

var containerName = 'onPremisesData'

var logAnalyticsWorkspaceName  = 'loganalytics-${suffix}'
var applicationInsightsName = appName

var eventHubNamespaceName = 'ehub-ns-${suffix}'
var eventHubName = 'ehub-onprem-ingestion'

var serviceBusNamespaceName = 'servicebus-${suffix}'
var serviceBusQueueName = 'sbus-onprem-ingestion'

var runtime = 'python'
var functionWorkerRuntime = runtime

var functionAppName = appName
var hostingPlanName = appName

var cosmosAccountName  = 'cosmos-${suffix}'
var storageAccountName = 'storage${suffix}'


var failOverlocations = [
  {
    locationName: location
    failoverPriority: 0
    isZoneRedundant: false
  }
]

// Creation of Cosmos DB Account, Database and Container that will 
// contain data to to simulate the results of a call to an internal API
// or a third-party service

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: toLower(cosmosAccountName)
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    locations: failOverlocations
    databaseAccountOfferType: 'Standard'
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-05-15' = {
  name: '${cosmosAccount.name}/${databaseName}'
  properties: {
    resource: {
      id: databaseName
    }
  }
}

resource sqlContainerName 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-06-15' = {
  parent: database
  name: containerName
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
    }
    options: {}
  }
}

var cosmosConnectionString = cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString
// Creation of a storage account with an Table. The storage account is 
// also used by Azure Functions

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'Storage'

  resource tablestorage 'tableServices' = {
    name: 'default'

    resource table 'tables' = {
      name: 'ingesteddata'
      }
    }
}




// Creation of the Log-Analytics worksspace and the 
// Application Insights resource attached to it
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}


resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}


resource eventHubNamespace 'Microsoft.EventHub/namespaces@2022-10-01-preview' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: eventHubSku
    tier: eventHubSku
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
  }

  // Grant Listen and Send rights on the event hub
  resource eventHubNamespaceAccessPolicy 'authorizationRules@2022-10-01-preview' = {
    name: 'ListenSend'
    properties: {
      rights: [
        'Listen'
        'Send'
      ]
    }
  }

}


resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2022-10-01-preview' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    messageRetentionInDays: 7
    partitionCount: 1
  }
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {}

  // Grant Listen and Send on the event hub
  resource eventHubNamespaceAccessPolicy 'authorizationRules@2022-10-01-preview' = {
    name: 'ListenSend'
    properties: {
      rights: [
        'Listen'
        'Send'
      ]
    }
  }
}

var eventHubNamespaceConnectionString = listKeys(eventHubNamespace::eventHubNamespaceAccessPolicy.id, eventHubNamespace.apiVersion).primaryConnectionString

var serviceBusNamespaceConnectionString = listKeys(serviceBusNamespace::eventHubNamespaceAccessPolicy.id, serviceBusNamespace.apiVersion).primaryConnectionString

resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2022-01-01-preview' = {
  parent: serviceBusNamespace
  name: serviceBusQueueName
  properties: {
    lockDuration: 'PT5M'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    requiresSession: false
    defaultMessageTimeToLive: 'P10675199DT2H48M5.4775807S'
    deadLetteringOnMessageExpiration: false
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    maxDeliveryCount: 10
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
    enableExpress: false
  }
}

// Creation of the App service plan and the Azure Function App
resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: hostingPlanName
  location: location
  kind: 'linux'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      linuxFxVersion: 'python|3.9'
      connectionStrings: [
        {
          name: 'EVENTHUBS_NS_CONNECTION_STRING'
          connectionString: eventHubNamespaceConnectionString
        }
        {
          name: 'SERVICEBUS_NS_CONNECTION_STRING'
          connectionString: serviceBusNamespaceConnectionString
        }
        {
          name: 'COSMOSDB_CONNECTION_STRING'
          connectionString: cosmosConnectionString
        }

      ]
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'PYTHON_ENABLE_WORKER_EXTENSIONS'
          value: '1'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

@description('This is the built-in Contributor role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor')
resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: storageAccount
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}


resource contributorRoleAssignmentStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('fnapp', storageAccount.id, contributorRoleDefinition.id)
  scope: storageAccount
  properties: {
    roleDefinitionId: contributorRoleDefinition.id
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'

  }
}

resource contributorRoleAssignmentCosmos 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('fnapp', cosmosAccount.id, contributorRoleDefinition.id)
  scope: cosmosAccount
  properties: {
    roleDefinitionId: contributorRoleDefinition.id
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'

  }
}

output cosmosConnectionString string = cosmosConnectionString
output containerName string = containerName
output functionAppName string = functionAppName
