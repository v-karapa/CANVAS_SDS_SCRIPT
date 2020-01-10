#connect AzureAD
Connect-AzureAD

#create Azure application
$appName = "MSprofilesds"
$appURI = "http://sissync.microsoft.com/sdsappconnect"
$appHomePageUrl = "http://sissync.microsoft.com"
$appReplyURLs = "https://localhost:1234"

if(!($myApp = Get-AzureADApplication -Filter "DisplayName eq '$($appName)'"  -ErrorAction SilentlyContinue))
{
    $myApp = New-AzureADApplication -DisplayName $appName -IdentifierUris $appURI -Homepage $appHomePageUrl -ReplyUrls $appReplyURLs    
}

# Application (client) ID, tenant Name and secret
$clientId = (Get-AzureADApplication -Filter "DisplayName eq '$($appName)'" | select AppId).AppId
$ObjectId = (Get-AzureADApplication -Filter "DisplayName eq '$($appName)'" | select ObjectId).ObjectId
$tenantName = "9bb0d80d-8b9d-4f06-a1fe-ef5e06c8a537"
$resource = "https://graph.microsoft.com/"

#creating client secret
$startDate = Get-Date
$endDate = $startDate.AddYears(3)
$clientSecret = New-AzureADApplicationPasswordCredential -ObjectId $ObjectId -CustomKeyIdentifier "Secret05" -StartDate $startDate -EndDate $endDate


#apply permistions
$svcprincipalGraph = Get-AzureADServicePrincipal -All $true | ? { $_.DisplayName -match "Microsoft Graph" }

$svcprincipalGraph.AppRoles | FT ID, DisplayName
$svcprincipalGraph.Oauth2Permissions | FT ID, UserConsentDisplayName

$Pbi = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
$Pbi.ResourceAppId = $svcprincipalPbi.AppId

$delPermission13 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "b2f1b2fa-f35c-407c-979c-a858a808ba85","Scope" ## View all workspaces
#
#authenticate application
$Username = "admin@M365EDU032767.onmicrosoft.com"
$Password = "8QTTmXqnbS"

$ReqTokenBody = @{
     Grant_Type    = "Password"
    client_Id     = '61ef1a07-5f64-44c5-ad83-d3dc9713f989'
    Client_Secret = 'z@AdIRu-D]fBK6?ixlkiAgt5hlQzxx53'
    Username      = $Username
    Password      = $Password
    Scope         = "https://graph.microsoft.com/.default"
} 
$TokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/9bb0d80d-8b9d-4f06-a1fe-ef5e06c8a537/oauth2/v2.0/token" -Method POST -Body $ReqTokenBody



#domain and license for students&teachers 
$studomain = "M365EDU032767.onmicrosoft.com"
$teacherdomain = "M365EDU032767.onmicrosoft.com"
$studentlicense = '46c119d4-0379-4a9d-85e4-97c66d3f909e'
$teacherlicense = 'e97c048c-37a4-45fb-ab50-922fbf07a370'

#create synchronization profile
$apiUrl = 'https://graph.microsoft.com/beta/education/synchronizationProfiles'
$body = 
{
    "displayName": "NewProfile12",
    "dataProvider": {
        "@odata.type": "#Microsoft.Education.DataSync.educationCsvDataProvider",
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
        "@odata.type": "#Microsoft.Education.DataSync.educationIdentityCreationConfiguration",
        "userDomains": [
            {
                "appliesTo": "student",
                "name": "$studomain"
            },
            {
                "appliesTo": "teacher",
                "name": "$teacherdomain"
            }
        ]
    },
    "licensesToAssign": [
        {
            "appliesTo": "teacher",
            "skuIds": [
                "$teacherlicense"
            ]
        },
        {
            "appliesTo": "student",
            "skuIds": [
                "$studentlicense"
            ]
        }
    ]
}
Invoke-RestMethod -Headers @{Authorization = "Bearer $($TokenResponse.access_token)"} -Uri $apiUrl -Body $body -Method Post -ContentType 'application/json'

#get synchronization profile
$apiUrl = 'https://graph.microsoft.com/beta/education/synchronizationProfiles'
Invoke-RestMethod -Headers @{Authorization = "Bearer $($TokenResponse.access_token)"} -Uri $apiUrl -Method get -ContentType 'application/json'

#create uploadurl
$apiUrl = 'https://graph.microsoft.com/beta/education/synchronizationProfiles'
$Data = Invoke-RestMethod -Headers @{Authorization = "Bearer $($Tokenresponse.access_token)"} -Uri $apiUrl -Method get
$a = $Data | select value

#create batch file using sas token value

#run azcopy file #upload files using azcopy
start-process -FilePath C:\Users\v-karapa\Desktop\SDS_UPLOAD_API\sastoken.cmd

#start sync
$apiUrl = 'https://graph.microsoft.com/beta/education/synchronizationProfiles/$syncprofile/start'
Invoke-RestMethod -Headers @{Authorization = "Bearer $($Tokenresponse.access_token)"} -Uri $apiUrl -Method post -ContentType 'application/json'