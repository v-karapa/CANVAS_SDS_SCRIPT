##########Canfile Upload##########
#check configuration file is available or not
param(
      [Parameter(Mandatory=$true)][System.String]$appName,
      [Parameter(Mandatory=$true)][System.String]$Username,
      [Parameter(Mandatory=$true)][System.String]$Password,
      [Parameter(Mandatory=$true)][System.String]$SyncprofileName
      )

if (-not (test-path conf.json))
{
#connect AzureAD
write-host "provide your login credentials"
Connect-AzureAD

#create Azure application
      
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
$Domaininfo = $tenant.VerifiedDomains
$Domain = $Domaininfo.Name

#Getting SKuid
$skuid = Get-AzureADSubscribedSku | select 
$studentskuIds = $skuid | where {($_.skuPartNumber -eq 'M365EDU_A5_STUDENT')}
$studentskuIds.skuId
$teacherskuIds = $skuid | where {($_.skuPartNumber -eq 'M365EDU_A5_FACULTY')}
$teacherskuIds.skuId
$studentlicense = $studentskuIds.skuId
$teacherlicense = $teacherskuIds.skuId

#creating client secret
$startDate = Get-Date
$endDate = $startDate.AddYears(3)
$clientSecret = New-AzureADApplicationPasswordCredential -ObjectId $ObjectId -CustomKeyIdentifier "Secret01" -StartDate $startDate -EndDate $endDate
$Client_Secret = $clientSecret.Value
        
    $conf = [ordered]@{
    SyncprofileName= $SyncprofileName    
    client_Id     = $client_Id
    Client_Secret = $Client_Secret
    Username      = $Username
    Password      = $Password
    Tenantid      = $tenantid
    Domain        = $Domain
    Teacherlicense= $teacherlicense
    Studentlicense= $studentlicense
    }

$conf | ConvertTo-Json | Out-File -FilePath conf.json

}

else
  {
    $conffile = get-content conf.json | ConvertFrom-Json
  }

##Token generation
    $SyncprofileName= $conffile.SyncprofileName
    $client_Id     = $conffile.client_Id
    $Client_Secret = $conffile.Client_Secret
    $Username      = $conffile.Username
    $Password      = $conffile.Password
    $tenantid      = $conffile.Tenantid
    $Domain        = $conffile.Domain
    $teacherlicense    = $conffile.Teacherlicense
    $studentlicense    = $conffile.Studentlicense
    
    $loginurl = "https://login.microsoftonline.com/" + "$tenantid" + "/oauth2/v2.0/token"

    $ReqTokenBody = @{
     Grant_Type    = "Password"
    client_Id     = $client_Id
    Client_Secret = $Client_Secret
    Username      = $Username
    Password      = $Password
    Scope         = "https://graph.microsoft.com/.default"
} 

$Token = Invoke-RestMethod -Uri "$loginurl" -Method POST -Body $ReqTokenBody


# Create header
$Header = @{
    Authorization = "$($token.token_type) $($token.access_token)"
}

#####create synchronization profiles####

$body = 
{
    displayName = $New_synchronization_profile_Name
    dataProvider = 
        @{(odata.type) = "#Microsoft.Education.DataSync.educationCsvDataProvider"
        customizations = {
            student = {optionalPropertiesToSync = ("State ID", "Middle Name")}
        }
    }
    identitySynchronizationConfiguration = 
        @{(odata.type) = "#Microsoft.Education.DataSync.educationIdentityCreationConfiguration"
        userDomains = {
            {
                appliesTo = "teacher",
                name = $Domain
            },
            {
                appliesTo = "teacher",
                name = $Domain
            }
        }
    }
    licensesToAssign = {
        {
            appliesTo = "teacher",
            skuIds = $teacherlicense
             },
        {
            appliesTo = "student",
            skuIds = $studentlicense
            }
    }
}
$createdprofile = Invoke-RestMethod -Headers $Header -Uri $Uri -Body $body -Method Post -ContentType 'application/json'

#create upload url
$Uri1 = "https://graph.microsoft.com/beta/education/synchronizationProfiles/f7ae02dd-de69-415c-bf24-9b8f22af6d9b/uploadUrl"
$uploadurl = Invoke-RestMethod -Uri $Uri1 -Headers $Header -Method Get -ContentType "application/json"

$b = $uploadurl.value
$a = 'C:\azcopy\azcopy.exe copy "C:\local\*.*" '
$c = ' --recursive=true --check-length=false'

$u = "$a" + "'$b'" + "$c"
$u >sastoken.cmd

#run azcopy file and upload files using azcopy
start-process -FilePath sastoken.cmd

#Run start sync profile
$UriStart = "https://graph.microsoft.com/beta/education/synchronizationProfiles/2f7c47a3-866e-4510-a926-70d7434b2b18/start"
$start = Invoke-RestMethod -Uri $UriStart -Headers $Header -Method Post -ContentType "application/json"
$start

