param ($subscriptionId, $tenantId, $deploymentNameBuild, $deploymentNameRelease, $namePrefix, $apiName, $apiPath, $appReaderPassword, $appWriterPassword)

invoke-restmethod -uri "https://artii.herokuapp.com/make?text=Azure-Deploy&font=speed" -DisableKeepAlive

Write-Host "Setting the paramaters:"
$location = "West Europe"
$resourceGroup = "$namePrefix-rg"
$buildBicepPath = ".\deploy\build\main.bicep"
$releaseBicepPath = ".\deploy\release\ais-deploy-api.bicep"
$appInsightsName = "$namePrefix-ai"
$appRegProvider = "$namePrefix-provider"
$appRegReader = "$namePrefix-consumer-reader"
$appRoleReader = "Api.Reader" # If you want to change this, you must also change the name in the manifest.json
$appRoleWriter = "Api.Writer" # If you want to change this, you must also change the name in the manifest.json
$appRegWriter = "$namePrefix-consumer-writer"

Write-Host "Subscription id: "$subscriptionId
Write-Host "Tenant id: "$tenantId
Write-Host "Deployment Name Build: "$deploymentNameBuild
Write-Host "Deployment Name Release: "$deploymentNameRelease
Write-Host "Resource Group: "$resourceGroup
Write-Host "Location: "$location
Write-Host "Build by Bicep File: "$buildBicepPath
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

Write-Host "Build"
Write-Host "Deploy Infrastructure as Code:"
New-AzSubscriptionDeployment -name $deploymentNameBuild -namePrefix $namePrefix -location $location -TemplateFile $buildBicepPath

Write-Host "Release"
Write-Host "Create App Registrations:"
Write-Host "Provider"
$appIdProvider = az ad app list --display-name $appRegProvider --query [].appId --output tsv
if ($appIdProvider) { 
    Write-Host "AppId Provider present."
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
Write-Host "Object Id Service Principal: "$ObjectIdProviderSP
$ObjectIdRoleReader = az ad app show --id $appIdProvider --query "appRoles[?value == '${appRoleReader}'].id" --output tsv
Write-Host "Object Id Role Reader: "$ObjectIdRoleReader
$ObjectIdRoleWriter = az ad app show --id $appIdProvider --query "appRoles[?value == '${appRoleWriter}'].id" --output tsv
Write-Host "Object Id Role Writer: "$ObjectIdRoleWriter

Write-Host "Reader"
$ObjectIdReader = az ad app list --display-name $appRegReader --query [].objectId --output tsv
if ($ObjectIdReader) {
    Write-Host "Object Id Reader present."
} else 
{
    $appNameReader = $appRegReader
    $identifierUriReader = "api://$appRegReader"
    $appRegistrationReader = az ad app create --display-name $appNameReader --identifier-uris $identifierUriReader --password $appReaderPassword --credential-description 'api'
    $appReader = $appRegistrationReader | ConvertFrom-Json
    $ObjectIdReader = $appReader.objectId
}
Write-Host "Object Id Reader: "$ObjectIdReader

Write-Host "Writer"
$ObjectIdWriter = az ad app list --display-name $appRegWriter --query [].objectId --output tsv
if ($ObjectIdWriter) {
    Write-Host "Object Id Writer present."
} else 
{
    $appNameWriter = $appRegWriter
    $identifierUriWriter = "api://$appRegWriter"
    $appRegistrationWriter = az ad app create --display-name $appNameWriter --identifier-uris $identifierUriWriter --password $appWriterPassword --credential-description 'api'
    $appWriter = $appRegistrationWriter | ConvertFrom-Json
    $ObjectIdWriter = $appWriter.objectId
}
Write-Host "Object Id Writer: "$ObjectIdWriter

Write-Host "Retrieve API Management Instance Name:"
$apimName = az apim list --resource-group $resourceGroup --subscription $subscriptionId --query "[].{Name:name}" -o tsv
Write-Host "Azure API Management: "$apimName

Write-Host "Release API definition to API Management:"
New-AzResourceGroupDeployment -Name $deploymentNameRelease -ResourceGroupName $resourceGroup -apimName $apimName -appInsightsName $appInsightsName -tenantId $tenantId -providerAppId $appIdProvider -appRoleReader $appRoleReader -appRoleWriter $appRoleWriter -apiName $apiName -apiPath $apiPath -TemplateFile $releaseBicepPath

# When running manually, you can only run these commands from the Cloud Shell.
# Connect-AzureAD does not complete the authentication from PowerShell locally.
# Write-Host "Assign roles to App Registrations"
# Install-Module AzureAD
# Import-Module AzureAD
# Connect-AzureAD -TenantId $tenantId
# New-AzureADServiceAppRoleAssignment -ObjectId $ObjectIdReader -Id $ObjectIdRoleReader -PrincipalId $ObjectIdReader -ResourceId $ObjectIdProviderSP
# New-AzureADServiceAppRoleAssignment -ObjectId $ObjectIdWriter -Id $ObjectIdRoleWriter -PrincipalId $ObjectIdWriter -ResourceId $ObjectIdProviderSP