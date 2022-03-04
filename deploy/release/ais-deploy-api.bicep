targetScope = 'resourceGroup'

param apimName string
param appInsightsName string
param apiName string
param apiPath string
param tenantId string
param providerAppId string
param appRoleReader string
param appRoleWriter string

var apiPolicyGetOperation = '<policies><inbound><base /><validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized. Access token is missing or invalid."><openid-config url="https://login.microsoftonline.com/${tenantId}/.well-known/openid-configuration" /><audiences><audience>${providerAppId}</audience></audiences><issuers><issuer>https://sts.windows.net/${tenantId}/</issuer></issuers><required-claims><claim name="roles" match="any"><value>${appRoleReader}</value><value>${appRoleWriter}</value></claim></required-claims></validate-jwt><mock-response status-code="200" content-type="application/json" /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
var apiPolicyPostOperation = '<policies><inbound><base /><validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized. Access token is missing or invalid."><openid-config url="https://login.microsoftonline.com/${tenantId}/.well-known/openid-configuration" /><audiences><audience>${providerAppId}</audience></audiences><issuers><issuer>https://sts.windows.net/${tenantId}/</issuer></issuers><required-claims><claim name="roles" match="all"><value>${appRoleWriter}</value></claim></required-claims></validate-jwt><mock-response status-code="200" content-type="application/json" /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'

resource apiManagement 'Microsoft.ApiManagement/service@2020-12-01' existing = {
  name: apimName
}

resource apiManagementLogger 'Microsoft.ApiManagement/service/loggers@2020-12-01' existing = {
  name: '${apimName}/${appInsightsName}'
}

resource apimApi 'Microsoft.ApiManagement/service/apis@2020-12-01' = {
  name: toLower(apiName)
  parent: apiManagement
  properties: {
    path: apiPath
    apiRevision: '1'
    displayName: apiName
    subscriptionRequired: false
    protocols: [
      'https'
    ]
  }
}

resource apiOperationGet 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' = {
  name: 'GET'
  parent: apimApi
  properties: {
    displayName: 'Get'
    method: 'GET'
    urlTemplate: '/get'
    description: 'Get operation with OAuth validation and mocking response.'
  }
}

resource apiOperationPost 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' = {
  name: 'POST'
  parent: apimApi
  properties: {
    displayName: 'Post'
    method: 'POST'
    urlTemplate: '/post'
    description: 'Post operation with OAuth validation and mocking response.'
  }
}

resource apiGetPolicies 'Microsoft.ApiManagement/service/apis/operations/policies@2020-12-01' = {
  name: 'policy'
  parent: apiOperationGet
  properties: {
    value: apiPolicyGetOperation
    format: 'rawxml'
  }
}

resource apiPostPolicies 'Microsoft.ApiManagement/service/apis/operations/policies@2020-12-01' = {
  name: 'policy'
  parent: apiOperationPost
  properties: {
    value: apiPolicyPostOperation
    format: 'rawxml'
  }
}

resource apiMonitoring 'Microsoft.ApiManagement/service/apis/diagnostics@2020-06-01-preview' = {
  name: 'applicationinsights'
  parent: apimApi
  properties: {
    alwaysLog: 'allErrors'
    loggerId: apiManagementLogger.id  
    logClientIp: true
    httpCorrelationProtocol: 'W3C'
    verbosity: 'verbose'
    operationNameFormat: 'Url'
  }
}
