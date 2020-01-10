﻿##########Canfile Upload##########
#check configuration file is available or not

if (-not (test-path conf.json)){

#connect AzureAD
Connect-AzureAD

#create Azure application
param(
      [Parameter(Mandatory=$true)][System.String]$appName,
      [Parameter(Mandatory=$true)][System.String]$Username,
      [Parameter(Mandatory=$true)][System.String]$Password
      )      
        $appHomePageUrl = "http://sissync.microsoft.com"
        $appURI = "http://sissync.microsoft.com/" + "$appName"
        $appReplyURLs = "https://localhost:1234"

if(!($myApp = Get-AzureADApplication -Filter "DisplayName eq '$($appName)'"  -ErrorAction SilentlyContinue))
{
    $myApp = New-AzureADApplication -DisplayName $appName -IdentifierUris $appURI -Homepage $appHomePageUrl -ReplyUrls $appReplyURLs    
}

# Application (client) ID, tenant Name
$client_Id = (Get-AzureADApplication -Filter "DisplayName eq '$($appName)'" | select AppId).AppId
$ObjectId = (Get-AzureADApplication -Filter "DisplayName eq '$($appName)'" | select ObjectId).ObjectId
$resource = "https://graph.microsoft.com/"
$tenant = Get-AzureADTenantDetail
$tenantid = $tenant.ObjectId

#creating client secret
$startDate = Get-Date
$endDate = $startDate.AddYears(3)
$clientSecret = New-AzureADApplicationPasswordCredential -ObjectId $ObjectId -CustomKeyIdentifier "Secret01" -StartDate $startDate -EndDate $endDate
$Client_Secret = $clientSecret.Value
        
    $conf = [ordered]@{    
    client_Id     = $client_Id
    Client_Secret = $Client_Secret
    Username      = $Username
    Password      = $Password
    Tenantid      = $tenantid
    }

$conf | ConvertTo-Json | Out-File -FilePath conf.json

}

else
  {
    $conffile = get-content conf.json | ConvertFrom-Json
  }

##Token generation
    $confclient_Id     = $conffile.client_Id
    $confClient_Secret = $conffile.Client_Secret
    $confUsername      = $conffile.Username
    $confPassword      = $conffile.Password
    $conftenantid      = $conffile.Tenantid
    $loginurl = "https://login.microsoftonline.com/" + "$conftenantid" + "/oauth2/v2.0/token"

    $ReqTokenBody = @{
     Grant_Type    = "Password"
    client_Id     = $confclient_Id
    Client_Secret = $confClient_Secret
    Username      = $confUsername
    Password      = $confPassword
    Scope         = "https://graph.microsoft.com/.default"
} 

$TokenResponse = Invoke-RestMethod -Uri "$loginurl" -Method POST -Body $ReqTokenBody


# Create header
$Header = @{
    Authorization = "$($token.token_type) $($token.access_token)"
}
#get all syncronization profiles
$Uri = "https://graph.microsoft.com/beta/education/synchronizationProfiles"
$SyncProfiles = Invoke-RestMethod -Uri $Uri -Headers $Header -Method Get -ContentType "application/json"
$SyncProfiles.Value

#####create synchronization profiles####
#Getting SKuid

$Uri12 = "https://graph.microsoft.com/v1.0/subscribedSkus"
$start1 = Invoke-RestMethod -Uri $Uri12 -Headers $Header -Method get -ContentType "application/json"
$skuid = $start1.value | select skuId, skupartNumber

$studentskuIds = $skuid | where {($_.skuPartNumber -eq 'M365EDU_A5_STUDENT')}
$studentskuIds.skuId
$teacherskuIds = $skuid | where {($_.skuPartNumber -eq 'M365EDU_A5_FACULTY')}
$teacherskuIds.skuId


$studomain = "M365EDU032767.onmicrosoft.com"
$teacherdomain = "M365EDU032767.onmicrosoft.com"
$studentlicense = $studentskuIds.skuId
$teacherlicense = $teacherskuIds.skuId

$body = 
{
    displayName = 'NewProfile12',
    dataProvider = {
        "@odata.type" : '#Microsoft.Education.DataSync.educationCsvDataProvider',
        "customizations": {
            "student": {
                "optionalPropertiesToSync": [
                    "State ID",
                    "Middle Name"
                ]
            }
        }
    },
    "identitySynchronizationConfiguration": {
        "@odata.type" : "#Microsoft.Education.DataSync.educationIdentityCreationConfiguration",
        "userDomains": [
            {
                "appliesTo": "student",
                "name": "M365EDU032767.onmicrosoft.com"
            },
            {
                "appliesTo": "teacher",
                "name": "M365EDU032767.onmicrosoft.com"
            }
        ]
    },
    "licensesToAssign": [
        {
            "appliesTo": "teacher",
            "skuIds": [
                "e97c048c-37a4-45fb-ab50-922fbf07a370"
            ]
        },
        {
            "appliesTo": "student",
            "skuIds": [
                "46c119d4-0379-4a9d-85e4-97c66d3f909e"
            ]
        }
    ]
}
$createdprofile = Invoke-RestMethod -Headers $Header -Uri $Uri -Body $body -Method Post -ContentType 'application/json'

#upload url
$Uri1 = "https://graph.microsoft.com/beta/education/synchronizationProfiles/f7ae02dd-de69-415c-bf24-9b8f22af6d9b/uploadUrl"
$uploadurl = Invoke-RestMethod -Uri $Uri1 -Headers $Header -Method Get -ContentType "application/json"

$b = $uploadurl.value
$a = 'C:\azcopy\azcopy.exe copy "C:\local\*.*" '
$c = ' --recursive=true --check-length=false'

$u = "$a" + "'$b'" + "$c"
$u >sastoken.cmd

#run azcopy file #upload files using azcopy
start-process -FilePath sastoken.cmd

#Run start sync profile
$UriStart = "https://graph.microsoft.com/beta/education/synchronizationProfiles/2f7c47a3-866e-4510-a926-70d7434b2b18/start"
$start = Invoke-RestMethod -Uri $UriStart -Headers $Header -Method Post -ContentType "application/json"
$start

