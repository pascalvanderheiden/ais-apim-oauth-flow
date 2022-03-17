param ($subscriptionId, $tenantId, $deploymentNameBuild, $deploymentNameRelease, $namePrefix, $apiName, $apiPath, $appReaderPassword, $appWriterPassword)

Write-Host "Setting the paramaters:"
$location = "West Europe"
$resourceGroup = "$namePrefix-rg"
$buildBicepPath = ".\deploy\build\main.bicep"
$releaseBicepPath = ".\deploy\release\ais-deploy-api.bicep"
$appInsightsName = "$namePrefix-ai"
$appRegProvider = "$namePrefix-provider"
$appRegReader = "$namePrefix-consumer-reader"
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
.\deploy\release\release-appreg-api.ps1 -subscriptionId $subscriptionId -tenantId $tenantId -deploymentNameRelease $deploymentNameRelease -namePrefix $namePrefix -apiName $apiName -apiPath $apiPath -appReaderPassword $appReaderPassword -appWriterPassword $appWriterPassword