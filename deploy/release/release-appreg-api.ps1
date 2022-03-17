param ($subscriptionId, $tenantId, $deploymentNameRelease, $namePrefix, $apiName, $apiPath, [secureString]$appReaderPassword, [secureString]$appWriterPassword)

Write-Host "Setting the paramaters:"
$resourceGroup = "$namePrefix-rg"
$releaseBicepPath = ".\deploy\release\ais-deploy-api.bicep"
$appInsightsName = "$namePrefix-ai"
$appRegProvider = "$namePrefix-provider"
$appRegReader = "$namePrefix-consumer-reader"
$appRoleReader = "Api.Reader" # If you want to change this, you must also change the name in the manifest.json
$appRoleWriter = "Api.Writer" # If you want to change this, you must also change the name in the manifest.json
$appRegWriter = "$namePrefix-consumer-writer"
$ReaderPassword = ConvertFrom-SecureString -SecureString $appReaderPassword -AsPlainText
$WriterPassword = ConvertFrom-SecureString -SecureString $appWriterPassword -AsPlainText

Write-Host "Subscription id: "$subscriptionId
Write-Host "Tenant id: "$tenantId
Write-Host "Deployment Name Release: "$deploymentNameRelease
Write-Host "Resource Group: "$resourceGroup
Write-Host "Release by Bicep File: "$releaseBicepPath
Write-Host "Application Insights Name: "$appInsightsName 
Write-Host "Api Name: "$apiName 
Write-Host "Api Path: "$apiPath
Write-Host "App Registration Provider: "$appRegProvider
Write-Host "App Registration Consumer Reader: "$appRegReader
Write-Host "App Registration Consumer Writer: "$appRegWriter

Write-Host "Login to Azure:"
Connect-AzAccount
Set-AzContext -Subscription $subscriptionId

Write-Host "Release"
Write-Host "Create App Registrations:"
Write-Host "Provider"
$appIdProvider = az ad app list --display-name $appRegProvider --query [].appId --output tsv
if ($appIdProvider) { 
    Write-Host "Provider present."
    $ObjectIdProviderSP=(az ad sp list --display-name $appRegProvider --query [].objectId --output tsv) 
} else 
{ 
    $appNameProvider = $appRegProvider
    $identifierUriProvider = "api://$appRegProvider"
    $appRegistrationProvider = az ad app create --display-name $appNameProvider --identifier-uris $identifierUriProvider --app-roles .\deploy\release\manifest.json
    $appProvider = $appRegistrationProvider | ConvertFrom-Json
    $appIdProvider = $appProvider.appId
    $ObjectIdProviderSP=(az ad sp create --id $appIdProvider --query objectId --output tsv) 
}
Write-Host "App Id Provider: "$appIdProvider
Write-Host "Object Id Provider: "$ObjectIdProviderSP
$ObjectIdRoleReader = az ad app show --id $appIdProvider --query "appRoles[?value == '${appRoleReader}'].id" --output tsv
Write-Host "Object Id Role Reader: "$ObjectIdRoleReader
$ObjectIdRoleWriter = az ad app show --id $appIdProvider --query "appRoles[?value == '${appRoleWriter}'].id" --output tsv
Write-Host "Object Id Role Writer: "$ObjectIdRoleWriter

Write-Host "Reader"
$AppIdReader = az ad app list --display-name $appRegReader --query [].appId --output tsv
if ($AppIdReader) {
    Write-Host "Reader present."
    $ObjectIdReader=(az ad sp list --display-name $appRegReader --query [].objectId --output tsv)
} else 
{
    $appNameReader = $appRegReader
    $identifierUriReader = "api://$appRegReader"
    $appRegistrationReader = az ad app create --display-name $appNameReader --identifier-uris $identifierUriReader --password $ReaderPassword --credential-description 'api'
    $appReader = $appRegistrationReader | ConvertFrom-Json
    $AppIdReader = $appReader.appId
    $ObjectIdReader=(az ad sp create --id $AppIdReader --query objectId --output tsv) 
}
Write-Host "Object Id Reader: "$ObjectIdReader

Write-Host "Writer"
$AppIdWriter = az ad app list --display-name $appRegWriter --query [].appId --output tsv
if ($AppIdWriter) {
    Write-Host "Writer present."
    $ObjectIdWriter=(az ad sp list --display-name $appRegWriter --query [].objectId --output tsv)
} else 
{
    $appNameWriter = $appRegWriter
    $identifierUriWriter = "api://$appRegWriter"
    $appRegistrationWriter = az ad app create --display-name $appNameWriter --identifier-uris $identifierUriWriter --password $WriterPassword --credential-description 'api'
    $appWriter = $appRegistrationWriter | ConvertFrom-Json
    $AppIdWriter = $appWriter.appId
    $ObjectIdWriter=(az ad sp create --id $AppIdWriter --query objectId --output tsv)
}
Write-Host "Object Id Writer: "$ObjectIdWriter

Write-Host "Retrieve API Management Instance Name:"
$apimName = az apim list --resource-group $resourceGroup --subscription $subscriptionId --query "[].{Name:name}" -o tsv
Write-Host "Azure API Management: "$apimName

Write-Host "Release API definition to API Management:"
New-AzResourceGroupDeployment -Name $deploymentNameRelease -ResourceGroupName $resourceGroup -apimName $apimName -appInsightsName $appInsightsName -tenantId $tenantId -providerAppId $appIdProvider -appRoleReader $appRoleReader -appRoleWriter $appRoleWriter -apiName $apiName -apiPath $apiPath -TemplateFile $releaseBicepPath

# When running manually, you can only run these commands from the Cloud Shell.
# Connect-AzureAD does not complete the authentication from PowerShell locally.
Write-Host "Assign roles to App Registrations"
Write-Host "Copy the commands below, and execute those in the Cloud Shell:" -ForegroundColor 'Red'
Write-Host "Connect-AzureAD -TenantId "$tenantId -ForegroundColor 'Green'
Write-Host "New-AzureADServiceAppRoleAssignment -ObjectId $ObjectIdReader -Id $ObjectIdRoleReader -PrincipalId $ObjectIdReader -ResourceId $ObjectIdProviderSP" -ForegroundColor 'Green'
Write-Host "New-AzureADServiceAppRoleAssignment -ObjectId $ObjectIdWriter -Id $ObjectIdRoleWriter -PrincipalId $ObjectIdWriter -ResourceId $ObjectIdProviderSP" -ForegroundColor 'Green'