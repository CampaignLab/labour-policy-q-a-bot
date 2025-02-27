targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

param resourceToken string = toLower(uniqueString(subscription().id, environmentName, location))

@description('Location for all resources.')
param location string

@description('Name of App Service plan')
param hostingPlanName string = '${environmentName}-hosting-plan-${resourceToken}'

@description('The pricing tier for the App Service plan')
@allowed([
  'F1'
  'D1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1'
  'P2'
  'P3'
  'P4'
])
param hostingPlanSku string = 'B3'

@description('Name of Web App')
param websiteName string = '${environmentName}-website-${resourceToken}'

@description('Name of Application Insights')
param applicationInsightsName string = '${environmentName}-appinsights-${resourceToken}'

@description('Use semantic search')
param azureSearchUseSemanticSearch string = 'false'

@description('Semantic search config')
param azureSearchSemanticSearchConfig string = 'default'

@description('Is the index prechunked')
param azureSearchIndexIsPrechunked string = 'false'

@description('Top K results')
param azureSearchTopK string = '5'

@description('Enable in domain')
param azureSearchEnableInDomain string = 'false'

@description('Content columns')
param azureSearchContentColumns string = 'content'

@description('Filename column')
param azureSearchFilenameColumn string = 'filename'

@description('Title column')
param azureSearchTitleColumn string = 'title'

@description('Url column')
param azureSearchUrlColumn string = 'url'

@description('Name of Azure OpenAI Resource')
param azureOpenAIResourceName string = '${environmentName}-openai-${resourceToken}'

@description('Name of Azure OpenAI Resource SKU')
param azureOpenAISkuName string = 'S0'

@description('Azure OpenAI Model Deployment Name')
param azureOpenAIModel string = 'gpt-35-turbo'

@description('Azure OpenAI Model Name')
param azureOpenAIModelName string = 'gpt-35-turbo'

param azureOpenAIModelVersion string = '0613'

@description('Orchestration strategy: openai_function or langchain str. If you use a old version of turbo (0301), plese select langchain')
@allowed([
  'openai_function'
  'langchain'
])
param orchestrationStrategy string = 'langchain'

@description('Azure OpenAI Temperature')
param azureOpenAITemperature string = '0'

@description('Azure OpenAI Top P')
param azureOpenAITopP string = '1'

@description('Azure OpenAI Max Tokens')
param azureOpenAIMaxTokens string = '1000'

@description('Azure OpenAI Stop Sequence')
param azureOpenAIStopSequence string = '\n'

@description('Azure OpenAI System Message')
param azureOpenAISystemMessage string = 'You are an AI assistant that helps people find information.'

@description('Azure OpenAI Api Version')
param azureOpenAIApiVersion string = '2023-10-01-preview'

@description('Whether or not to stream responses from Azure OpenAI')
param azureOpenAIStream string = 'true'

@description('Azure OpenAI Embedding Model Deployment Name')
param azureOpenAIEmbeddingModel string = 'text-embedding-ada-002'

@description('Azure OpenAI Embedding Model Name')
param azureOpenAIEmbeddingModelName string = 'text-embedding-ada-002'

@description('Azure AI Search Resource')
param azureAISearchName string = '${environmentName}-search-${resourceToken}'

@description('The SKU of the search service you want to create. E.g. free or standard')
@allowed([
  'free'
  'basic'
  'standard'
  'standard2'
  'standard3'
])
param azureSearchSku string = 'standard'

@description('Azure AI Search Index')
param azureSearchIndex string = '${environmentName}-index-${resourceToken}'

@description('Azure AI Search Conversation Log Index')
param azureSearchConversationLogIndex string = 'conversations'

@description('Name of Storage Account')
param storageAccountName string = 'str${resourceToken}'

@description('Name of Function App for Batch document processing')
param functionName string = '${environmentName}-backend-${resourceToken}'

@description('Azure Form Recognizer Name')
param formRecognizerName string = '${environmentName}-formrecog-${resourceToken}'

@description('Azure Content Safety Name')
param contentSafetyName string = '${environmentName}-contentsafety-${resourceToken}'

@description('Azure Speech Service Name')
param speechServiceName string = '${environmentName}-speechservice-${resourceToken}'

param newGuidString string = newGuid()
param searchTag string = 'chatwithyourdata-sa'
param useKeyVault bool

@description('Id of the user or app to assign application roles')
param principalId string = ''

@allowed([
  'rbac'
  'keys'
])
param authType string

var blobContainerName = 'documents'
var queueName = 'doc-processing'
var clientKey = '${uniqueString(guid(subscription().id, deployment().name))}${newGuidString}'
var eventGridSystemTopicName = 'doc-processing'
var tags = { 'azd-env-name': environmentName }
var rgName = 'rg-${environmentName}'
var keyVaultName = 'kv-${resourceToken}'

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
  tags: tags
}

// Store secrets in a keyvault
module keyvault './core/security/keyvault.bicep' = if (useKeyVault || authType == 'rbac') {
  name: 'keyvault'
  scope: rg
  params: {
    name: keyVaultName
    location: location
    tags: tags
    principalId: principalId
  }
}

module webaccess './core/security/keyvault-access.bicep' = if (useKeyVault) {
  name: 'web-keyvault-access'
  scope: rg
  params: {
    keyVaultName: keyVaultName
    principalId: web.outputs.FRONTEND_API_IDENTITY_PRINCIPAL_ID
  }
}

module adminwebaccess './core/security/keyvault-access.bicep' = if (useKeyVault) {
  name: 'adminweb-keyvault-access'
  scope: rg
  params: {
    keyVaultName: keyVaultName
    principalId: adminweb.outputs.WEBSITE_ADMIN_IDENTITY_PRINCIPAL_ID
  }
}

module functionaccess './core/security/keyvault-access.bicep' = if (useKeyVault) {
  name: 'function-keyvault-access'
  scope: rg
  params: {
    keyVaultName: keyVaultName
    principalId: function.outputs.FUNCTION_IDENTITY_PRINCIPAL_ID
  }
}

module openai 'core/ai/cognitiveservices.bicep' = {
  name: azureOpenAIResourceName
  scope: rg
  params: {
    name: azureOpenAIResourceName
    location: location
    tags: tags
    sku: {
      name: azureOpenAISkuName
    }
    deployments: [
      {
        name: azureOpenAIModel
        model: {
          format: 'OpenAI'
          name: azureOpenAIModelName
          version: azureOpenAIModelVersion
        }
        sku: {
          name: 'Standard'
          capacity: 30
        }
      }
      {
        name: azureOpenAIEmbeddingModel
        model: {
          format: 'OpenAI'
          name: azureOpenAIEmbeddingModelName
          version: '2'
        }
        capacity: 30
      }
    ]
  }
}

module speechService 'core/ai/cognitiveservices.bicep' = {
  scope: rg
  name: speechServiceName
  params: {
    name: speechServiceName
    location: location
    sku: {
      name: 'S0'
    }
    kind: 'SpeechServices'
  }
}

module storekeys './app/storekeys.bicep' = if (useKeyVault) {
  name: 'storekeys'
  scope: rg
  params: {
    keyVaultName: keyVaultName
    azureOpenAIName: openai.outputs.name
    azureAISearchName: search.outputs.name
    storageAccountName: storage.outputs.name
    formRecognizerName: formrecognizer.outputs.name
    contentSafetyName: contentsafety.outputs.name
    speechServiceName: speechServiceName
    rgName: rgName
  }
}

module search './core/search/search-services.bicep' = {
  name: azureAISearchName
  scope: rg
  params: {
    name: azureAISearchName
    location: location
    tags: {
      deployment: searchTag
    }
    sku: {
      name: azureSearchSku
    }
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http403'
      }
    }
  }
}

module hostingplan './core/host/appserviceplan.bicep' = {
  name: hostingPlanName
  scope: rg
  params: {
    name: hostingPlanName
    location: location
    sku: {
      name: hostingPlanSku
    }
    reserved: true
  }
}

module web './app/web.bicep' = {
  name: websiteName
  scope: rg
  params: {
    name: websiteName
    location: location
    tags: { 'azd-service-name': 'web' }
    appServicePlanId: hostingplan.outputs.name
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    azureOpenAIName: openai.outputs.name
    azureAISearchName: search.outputs.name
    storageAccountName: storage.outputs.name
    formRecognizerName: formrecognizer.outputs.name
    contentSafetyName: contentsafety.outputs.name
    speechServiceName: speechService.outputs.name
    openAIKeyName: useKeyVault ? storekeys.outputs.OPENAI_KEY_NAME : ''
    storageAccountKeyName: useKeyVault ? storekeys.outputs.STORAGE_ACCOUNT_KEY_NAME : ''
    formRecognizerKeyName: useKeyVault ? storekeys.outputs.FORM_RECOGNIZER_KEY_NAME : ''
    searchKeyName: useKeyVault ? storekeys.outputs.SEARCH_KEY_NAME : ''
    contentSafetyKeyName: useKeyVault ? storekeys.outputs.CONTENT_SAFETY_KEY_NAME : ''
    speechKeyName: useKeyVault ? storekeys.outputs.SPEECH_KEY_NAME : ''
    useKeyVault: useKeyVault
    keyVaultName: useKeyVault || authType == 'rbac' ? keyvault.outputs.name : ''
    keyVaultEndpoint: useKeyVault ? keyvault.outputs.endpoint : ''
    authType: authType
    appSettings: {
      APPINSIGHTS_CONNECTION_STRING: monitoring.outputs.applicationInsightsConnectionString
      AZURE_BLOB_ACCOUNT_NAME: storageAccountName
      AZURE_BLOB_CONTAINER_NAME: blobContainerName
      AZURE_CONTENT_SAFETY_ENDPOINT: 'https://${location}.api.cognitive.microsoft.com/'
      AZURE_FORM_RECOGNIZER_ENDPOINT: 'https://${location}.api.cognitive.microsoft.com/'
      AZURE_OPENAI_RESOURCE: azureOpenAIResourceName
      AZURE_OPENAI_MODEL: azureOpenAIModel
      AZURE_OPENAI_MODEL_NAME: azureOpenAIModelName
      AZURE_OPENAI_TEMPERATURE: azureOpenAITemperature
      AZURE_OPENAI_TOP_P: azureOpenAITopP
      AZURE_OPENAI_MAX_TOKENS: azureOpenAIMaxTokens
      AZURE_OPENAI_STOP_SEQUENCE: azureOpenAIStopSequence
      AZURE_OPENAI_SYSTEM_MESSAGE: azureOpenAISystemMessage
      AZURE_OPENAI_API_VERSION: azureOpenAIApiVersion
      AZURE_OPENAI_STREAM: azureOpenAIStream
      AZURE_OPENAI_EMBEDDING_MODEL: azureOpenAIEmbeddingModel
      AZURE_SEARCH_USE_SEMANTIC_SEARCH: azureSearchUseSemanticSearch
      AZURE_SEARCH_SERVICE: 'https://${azureAISearchName}.search.windows.net'
      AZURE_SEARCH_INDEX: azureSearchIndex
      AZURE_SEARCH_CONVERSATIONS_LOG_INDEX: azureSearchConversationLogIndex
      AZURE_SEARCH_SEMANTIC_SEARCH_CONFIG: azureSearchSemanticSearchConfig
      AZURE_SEARCH_INDEX_IS_PRECHUNKED: azureSearchIndexIsPrechunked
      AZURE_SEARCH_TOP_K: azureSearchTopK
      AZURE_SEARCH_ENABLE_IN_DOMAIN: azureSearchEnableInDomain
      AZURE_SEARCH_CONTENT_COLUMNS: azureSearchContentColumns
      AZURE_SEARCH_FILENAME_COLUMN: azureSearchFilenameColumn
      AZURE_SEARCH_TITLE_COLUMN: azureSearchTitleColumn
      AZURE_SEARCH_URL_COLUMN: azureSearchUrlColumn
      AZURE_SPEECH_SERVICE_NAME: speechServiceName
      AZURE_SPEECH_SERVICE_REGION: location
      ORCHESTRATION_STRATEGY: orchestrationStrategy
    }
  }
}

module adminweb './app/adminweb.bicep' = {
  name: '${websiteName}-admin'
  scope: rg
  params: {
    name: '${websiteName}-admin'
    location: location
    tags: { 'azd-service-name': 'adminweb' }
    appServicePlanId: hostingplan.outputs.name
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    azureOpenAIName: openai.outputs.name
    azureAISearchName: search.outputs.name
    storageAccountName: storage.outputs.name
    formRecognizerName: formrecognizer.outputs.name
    contentSafetyName: contentsafety.outputs.name
    speechServiceName: speechService.outputs.name
    openAIKeyName: useKeyVault ? storekeys.outputs.OPENAI_KEY_NAME : ''
    storageAccountKeyName: useKeyVault ? storekeys.outputs.STORAGE_ACCOUNT_KEY_NAME : ''
    formRecognizerKeyName: useKeyVault ? storekeys.outputs.FORM_RECOGNIZER_KEY_NAME : ''
    searchKeyName: useKeyVault ? storekeys.outputs.SEARCH_KEY_NAME : ''
    contentSafetyKeyName: useKeyVault ? storekeys.outputs.CONTENT_SAFETY_KEY_NAME : ''
    speechKeyName: useKeyVault ? storekeys.outputs.SPEECH_KEY_NAME : ''
    useKeyVault: useKeyVault
    keyVaultName: useKeyVault || authType == 'rbac' ? keyvault.outputs.name : ''
    keyVaultEndpoint: useKeyVault ? keyvault.outputs.endpoint : ''
    authType: authType
    appSettings: {
      APPINSIGHTS_INSTRUMENTATIONKEY: monitoring.outputs.applicationInsightsInstrumentationKey
      AZURE_BLOB_ACCOUNT_NAME: storageAccountName
      AZURE_BLOB_CONTAINER_NAME: blobContainerName
      AZURE_CONTENT_SAFETY_ENDPOINT: 'https://${location}.api.cognitive.microsoft.com/'
      AZURE_FORM_RECOGNIZER_ENDPOINT: 'https://${location}.api.cognitive.microsoft.com/'
      AZURE_OPENAI_RESOURCE: azureOpenAIResourceName
      AZURE_OPENAI_MODEL: azureOpenAIModel
      AZURE_OPENAI_MODEL_NAME: azureOpenAIModelName
      AZURE_OPENAI_TEMPERATURE: azureOpenAITemperature
      AZURE_OPENAI_TOP_P: azureOpenAITopP
      AZURE_OPENAI_MAX_TOKENS: azureOpenAIMaxTokens
      AZURE_OPENAI_STOP_SEQUENCE: azureOpenAIStopSequence
      AZURE_OPENAI_SYSTEM_MESSAGE: azureOpenAISystemMessage
      AZURE_OPENAI_API_VERSION: azureOpenAIApiVersion
      AZURE_OPENAI_STREAM: azureOpenAIStream
      AZURE_OPENAI_EMBEDDING_MODEL: azureOpenAIEmbeddingModel
      AZURE_SEARCH_SERVICE: 'https://${azureAISearchName}.search.windows.net'
      AZURE_SEARCH_INDEX: azureSearchIndex
      AZURE_SEARCH_USE_SEMANTIC_SEARCH: azureSearchUseSemanticSearch
      AZURE_SEARCH_SEMANTIC_SEARCH_CONFIG: azureSearchSemanticSearchConfig
      AZURE_SEARCH_INDEX_IS_PRECHUNKED: azureSearchIndexIsPrechunked
      AZURE_SEARCH_TOP_K: azureSearchTopK
      AZURE_SEARCH_ENABLE_IN_DOMAIN: azureSearchEnableInDomain
      AZURE_SEARCH_CONTENT_COLUMNS: azureSearchContentColumns
      AZURE_SEARCH_FILENAME_COLUMN: azureSearchFilenameColumn
      AZURE_SEARCH_TITLE_COLUMN: azureSearchTitleColumn
      AZURE_SEARCH_URL_COLUMN: azureSearchUrlColumn
      BACKEND_URL: 'https://${functionName}.azurewebsites.net'
      DOCUMENT_PROCESSING_QUEUE_NAME: queueName
      FUNCTION_KEY: clientKey
      ORCHESTRATION_STRATEGY: orchestrationStrategy
    }
  }
}

module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    applicationInsightsName: applicationInsightsName
    location: location
    tags: {
      'hidden-link:${resourceId('Microsoft.Web/sites', applicationInsightsName)}': 'Resource'
    }
    logAnalyticsName: '${environmentName}-logAnalytics-${resourceToken}'
    applicationInsightsDashboardName: 'dash-${applicationInsightsName}'
  }
}

module function './app/function.bicep' = {
  name: functionName
  scope: rg
  params: {
    name: functionName
    location: location
    tags: { 'azd-service-name': 'function' }
    appServicePlanId: hostingplan.outputs.name
    azureOpenAIName: openai.outputs.name
    azureAISearchName: search.outputs.name
    storageAccountName: storage.outputs.name
    formRecognizerName: formrecognizer.outputs.name
    contentSafetyName: contentsafety.outputs.name
    speechServiceName: speechService.outputs.name
    clientKey: clientKey
    openAIKeyName: useKeyVault ? storekeys.outputs.OPENAI_KEY_NAME : ''
    storageAccountKeyName: useKeyVault ? storekeys.outputs.STORAGE_ACCOUNT_KEY_NAME : ''
    formRecognizerKeyName: useKeyVault ? storekeys.outputs.FORM_RECOGNIZER_KEY_NAME : ''
    searchKeyName: useKeyVault ? storekeys.outputs.SEARCH_KEY_NAME : ''
    contentSafetyKeyName: useKeyVault ? storekeys.outputs.CONTENT_SAFETY_KEY_NAME : ''
    speechKeyName: useKeyVault ? storekeys.outputs.SPEECH_KEY_NAME : ''
    useKeyVault: useKeyVault
    keyVaultName: useKeyVault || authType == 'rbac' ? keyvault.outputs.name : ''
    keyVaultEndpoint: useKeyVault ? keyvault.outputs.endpoint : ''
    authType: authType
    appSettings: {
      APPINSIGHTS_INSTRUMENTATIONKEY: monitoring.outputs.applicationInsightsInstrumentationKey
      APPINSIGHTS_CONNECTION_STRING: monitoring.outputs.applicationInsightsConnectionString
      AZURE_BLOB_ACCOUNT_NAME: storageAccountName
      AZURE_BLOB_CONTAINER_NAME: blobContainerName
      AZURE_CONTENT_SAFETY_ENDPOINT: 'https://${location}.api.cognitive.microsoft.com/'
      AZURE_FORM_RECOGNIZER_ENDPOINT: 'https://${location}.api.cognitive.microsoft.com/'
      AZURE_OPENAI_MODEL: azureOpenAIModel
      AZURE_OPENAI_EMBEDDING_MODEL: azureOpenAIEmbeddingModel
      AZURE_OPENAI_RESOURCE: azureOpenAIResourceName
      AZURE_OPENAI_API_VERSION: azureOpenAIApiVersion
      AZURE_SEARCH_INDEX: azureSearchIndex
      AZURE_SEARCH_SERVICE: 'https://${azureAISearchName}.search.windows.net'
      DOCUMENT_PROCESSING_QUEUE_NAME: queueName
      FUNCTIONS_EXTENSION_VERSION: '~4'
      ORCHESTRATION_STRATEGY: orchestrationStrategy
      WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'false'
    }
  }
}

module formrecognizer 'core/ai/cognitiveservices.bicep' = {
  name: formRecognizerName
  scope: rg
  params: {
    name: formRecognizerName
    location: location
    tags: tags
    kind: 'FormRecognizer'
  }
}

module contentsafety 'core/ai/cognitiveservices.bicep' = {
  name: contentSafetyName
  scope: rg
  params: {
    name: contentSafetyName
    location: location
    tags: tags
    kind: 'ContentSafety'
  }
}

module eventgrid 'app/eventgrid.bicep' = {
  name: eventGridSystemTopicName
  scope: rg
  params: {
    name: eventGridSystemTopicName
    location: location
    storageAccountId: storage.outputs.id
    queueName: queueName
    blobContainerName: blobContainerName
  }
}

module storage 'core/storage/storage-account.bicep' = {
  name: storageAccountName
  scope: rg
  params: {
    name: storageAccountName
    location: location
    sku: {
      name: 'Standard_GRS'
    }
    containers: [
      {
        name: blobContainerName
        publicAccess: 'None'
      }
      {
        name: 'config'
        publicAccess: 'None'
      }
    ]
    queues: [
      {
        name: 'doc-processing'
      }
      {
        name: 'doc-processing-poison'
      }
    ]
  }
}

// USER ROLES
module storageRoleUser 'core/security/role.bicep' = if (authType == 'rbac') {
  scope: rg
  name: 'storage-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    principalType: 'User'
  }
}

// USER ROLES
module openaiRoleUser 'core/security/role.bicep' = if (authType == 'rbac') {
  scope: rg
  name: 'openai-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: 'a97b65f3-24c7-4388-baec-2e87135dc908'
    principalType: 'User'
  }
}

// USER ROLES
module openaiRoleUserContributor 'core/security/role.bicep' = if (authType == 'rbac') {
  scope: rg
  name: 'openai-role-user-contributor'
  params: {
    principalId: principalId
    roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
    principalType: 'User'
  }
}

// USER ROLES
module searchRoleUser 'core/security/role.bicep' = if (authType == 'rbac') {
  scope: rg
  name: 'search-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
    principalType: 'User'
  }
}

// SYSTEM IDENTITIES
module storageRoleBackend 'core/security/role.bicep' = if (authType == 'rbac') {
  scope: rg
  name: 'storage-role-backend'
  params: {
    principalId: adminweb.outputs.WEBSITE_ADMIN_IDENTITY_PRINCIPAL_ID
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    principalType: 'ServicePrincipal'
  }
}

// SYSTEM IDENTITIES
module openAIRoleBackend 'core/security/role.bicep' = if (authType == 'rbac') {
  scope: rg
  name: 'openai-role-backend'
  params: {
    principalId: adminweb.outputs.WEBSITE_ADMIN_IDENTITY_PRINCIPAL_ID
    roleDefinitionId: 'a97b65f3-24c7-4388-baec-2e87135dc908'
    principalType: 'ServicePrincipal'
  }
}

// SYSTEM IDENTITIES
module openAIRoleWeb 'core/security/role.bicep' = if (authType == 'rbac') {
  scope: rg
  name: 'openai-role-web'
  params: {
    principalId: web.outputs.FRONTEND_API_IDENTITY_PRINCIPAL_ID
    roleDefinitionId: 'a97b65f3-24c7-4388-baec-2e87135dc908'
    principalType: 'ServicePrincipal'
  }
}

// SYSTEM IDENTITIES
module openAIRoleFunction 'core/security/role.bicep' = if (authType == 'rbac') {
  scope: rg
  name: 'openai-role-function'
  params: {
    principalId: function.outputs.FUNCTION_IDENTITY_PRINCIPAL_ID
    roleDefinitionId: 'a97b65f3-24c7-4388-baec-2e87135dc908'
    principalType: 'ServicePrincipal'
  }
}

// SYSTEM IDENTITIES
module openAIRoleBackendContributor 'core/security/role.bicep' = if (authType == 'rbac') {
  scope: rg
  name: 'openai-role-backend-contributor'
  params: {
    principalId: adminweb.outputs.WEBSITE_ADMIN_IDENTITY_PRINCIPAL_ID
    roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
    principalType: 'ServicePrincipal'
  }
}

// SYSTEM IDENTITIES
module openAIRoleWebContributor 'core/security/role.bicep' = if (authType == 'rbac') {
  scope: rg
  name: 'openai-role-web-contributor'
  params: {
    principalId: web.outputs.FRONTEND_API_IDENTITY_PRINCIPAL_ID
    roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
    principalType: 'ServicePrincipal'
  }
}

// SYSTEM IDENTITIES
module openAIRoleFunctionContributor 'core/security/role.bicep' = if (authType == 'rbac') {
  scope: rg
  name: 'openai-role-function-contributor'
  params: {
    principalId: function.outputs.FUNCTION_IDENTITY_PRINCIPAL_ID
    roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
    principalType: 'ServicePrincipal'
  }
}

// SYSTEM IDENTITIES
module searchRoleBackend 'core/security/role.bicep' = if (authType == 'rbac') {
  scope: rg
  name: 'search-role-backend'
  params: {
    principalId: adminweb.outputs.WEBSITE_ADMIN_IDENTITY_PRINCIPAL_ID
    roleDefinitionId: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
    principalType: 'ServicePrincipal'
  }
}

// SYSTEM IDENTITIES
module searchRoleWeb 'core/security/role.bicep' = if (authType == 'rbac') {
  scope: rg
  name: 'search-role-web'
  params: {
    principalId: web.outputs.FRONTEND_API_IDENTITY_PRINCIPAL_ID
    roleDefinitionId: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
    principalType: 'ServicePrincipal'
  }
}

// SYSTEM IDENTITIES
module searchRoleFunction 'core/security/role.bicep' = if (authType == 'rbac') {
  scope: rg
  name: 'search-role-function'
  params: {
    principalId: function.outputs.FUNCTION_IDENTITY_PRINCIPAL_ID
    roleDefinitionId: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
    principalType: 'ServicePrincipal'
  }
}

// TODO: Streamline to one key=value pair
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output APPINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output APPINSIGHTS_INSTRUMENTATIONKEY string = monitoring.outputs.applicationInsightsInstrumentationKey

output AZURE_BLOB_CONTAINER_NAME string = blobContainerName
output AZURE_BLOB_ACCOUNT_NAME string = storageAccountName
output AZURE_BLOB_ACCOUNT_KEY string = useKeyVault ? storekeys.outputs.STORAGE_ACCOUNT_KEY_NAME : ''
output AZURE_CONTENT_SAFETY_ENDPOINT string = contentsafety.outputs.endpoint
output AZURE_CONTENT_SAFETY_KEY string = useKeyVault ? storekeys.outputs.CONTENT_SAFETY_KEY_NAME : ''
output AZURE_FORM_RECOGNIZER_ENDPOINT string = formrecognizer.outputs.endpoint
output AZURE_FORM_RECOGNIZER_KEY string = useKeyVault ? storekeys.outputs.FORM_RECOGNIZER_KEY_NAME : ''
output AZURE_KEY_VAULT_ENDPOINT string = useKeyVault ? keyvault.outputs.endpoint : ''
output AZURE_KEY_VAULT_NAME string = useKeyVault || authType == 'rbac' ? keyvault.outputs.name : ''
output AZURE_LOCATION string = location
output AZURE_OPENAI_MODEL_NAME string = azureOpenAIModelName
output AZURE_OPENAI_STREAM string = azureOpenAIStream
output AZURE_OPENAI_SYSTEM_MESSAGE string = azureOpenAISystemMessage
output AZURE_OPENAI_STOP_SEQUENCE string = azureOpenAIStopSequence
output AZURE_OPENAI_MAX_TOKENS string = azureOpenAIMaxTokens
output AZURE_OPENAI_TOP_P string = azureOpenAITopP
output AZURE_OPENAI_TEMPERATURE string = azureOpenAITemperature
output AZURE_OPENAI_API_VERSION string = azureOpenAIApiVersion
output AZURE_OPENAI_RESOURCE string = azureOpenAIResourceName
output AZURE_OPENAI_EMBEDDING_MODEL string = azureOpenAIEmbeddingModel
output AZURE_OPENAI_MODEL string = azureOpenAIModel
output AZURE_OPENAI_API_KEY string = useKeyVault ? storekeys.outputs.OPENAI_KEY_NAME : ''
output AZURE_SEARCH_KEY string = useKeyVault ? storekeys.outputs.SEARCH_KEY_NAME : ''
output AZURE_SEARCH_SERVICE string = search.outputs.endpoint
output AZURE_SEARCH_USE_SEMANTIC_SEARCH string = azureSearchUseSemanticSearch
output AZURE_SEARCH_SEMANTIC_SEARCH_CONFIG string = azureSearchSemanticSearchConfig
output AZURE_SEARCH_INDEX_IS_PRECHUNKED string = azureSearchIndexIsPrechunked
output AZURE_SEARCH_TOP_K string = azureSearchTopK
output AZURE_SEARCH_ENABLE_IN_DOMAIN string = azureSearchEnableInDomain
output AZURE_SEARCH_CONTENT_COLUMNS string = azureSearchContentColumns
output AZURE_SEARCH_FILENAME_COLUMN string = azureSearchFilenameColumn
output AZURE_SEARCH_TITLE_COLUMN string = azureSearchTitleColumn
output AZURE_SEARCH_URL_COLUMN string = azureSearchUrlColumn
output AZURE_SEARCH_INDEX string = azureSearchIndex
output AZURE_SPEECH_SERVICE_REGION string = location
output AZURE_SPEECH_SERVICE_KEY string = useKeyVault ? storekeys.outputs.SPEECH_KEY_NAME : ''
output AZURE_TENANT_ID string = tenant().tenantId
output DOCUMENT_PROCESSING_QUEUE_NAME string = queueName
output ORCHESTRATION_STRATEGY string = orchestrationStrategy
output USE_KEY_VAULT bool = useKeyVault
