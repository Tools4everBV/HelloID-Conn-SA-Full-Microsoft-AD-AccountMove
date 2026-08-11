# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

#HelloID variables
#Note: when running this script inside HelloID; portalUrl and API credentials are provided automatically (generate and save API credentials first in your admin panel!)
$portalUrl = "https://CUSTOMER.helloid.com"
$apiKey = "API_KEY"
$apiSecret = "API_SECRET"
$delegatedFormAccessGroupNames = @("") #Only unique names are supported. Groups must exist!
$delegatedFormCategories = @("Active Directory","User Management") #Only unique names are supported. Categories will be created if not exists
$script:debugLogging = $false #Default value: $false. If $true, the HelloID resource GUIDs will be shown in the logging
$script:duplicateForm = $false #Default value: $false. If $true, the HelloID resource names will be changed to import a duplicate Form
$script:duplicateFormSuffix = "_tmp" #the suffix will be added to all HelloID resource names to generate a duplicate form with different resource names

#The following HelloID Global variables are used by this form. No existing HelloID global variables will be overriden only new ones are created.
#NOTE: You can also update the HelloID Global variable values afterwards in the HelloID Admin Portal: https://<CUSTOMER>.helloid.com/admin/variablelibrary
$globalHelloIDVariables = [System.Collections.Generic.List[object]]@();

#Global variable #1 >> ADUsersMoveOU
$tmpName = @'
ADUsersMoveOU
'@ 
$tmpValue = @'
OU=Users,OU=enyoi,DC=enyoi,DC=local;OU=Marked for Deleteion,OU=Users,OU=enyoi,DC=enyoi,DC=local
'@ 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "False"});

#Global variable #2 >> ADUsersMoveSearchOU
$tmpName = @'
ADUsersMoveSearchOU
'@ 
$tmpValue = @'
OU=Users,OU=enyoi,DC=enyoi,DC=local;OU=UsersLite,OU=enyoi,DC=enyoi,DC=local
'@ 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "False"});


#make sure write-information logging is visual
$InformationPreference = "continue"

# Check for prefilled API Authorization header
if (-not [string]::IsNullOrEmpty($portalApiBasic)) {
    $script:headers = @{"authorization" = $portalApiBasic}
    Write-Information "Using prefilled API credentials"
} else {
    # Create authorization headers with HelloID API key
    $pair = "$apiKey" + ":" + "$apiSecret"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $key = "Basic $base64"
    $script:headers = @{"authorization" = $Key}
    Write-Information "Using manual API credentials"
}

# Check for prefilled PortalBaseURL
if (-not [string]::IsNullOrEmpty($portalBaseUrl)) {
    $script:PortalBaseUrl = $portalBaseUrl
    Write-Information "Using prefilled PortalURL: $script:PortalBaseUrl"
} else {
    $script:PortalBaseUrl = $portalUrl
    Write-Information "Using manual PortalURL: $script:PortalBaseUrl"
}

# Define specific endpoint URI
$script:PortalBaseUrl = $script:PortalBaseUrl.trim("/") + "/"  

# Make sure to reveive an empty array using PowerShell Core
function ConvertFrom-Json-WithEmptyArray([string]$jsonString) {
    # Running in PowerShell Core?
    if($IsCoreCLR -eq $true){
        $r = [Object[]]($jsonString | ConvertFrom-Json -NoEnumerate)
        return ,$r  # Force return value to be an array using a comma
    } else {
        $r = [Object[]]($jsonString | ConvertFrom-Json)
        return ,$r  # Force return value to be an array using a comma
    }
}

function Invoke-HelloIDGlobalVariable {
    param(
        [parameter(Mandatory)][String]$Name,
        [parameter(Mandatory)][String][AllowEmptyString()]$Value,
        [parameter(Mandatory)][String]$Secret
    )

    $Name = $Name + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        $uri = ($script:PortalBaseUrl + "api/v1/automation/variables/named/$Name")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false

        if ([string]::IsNullOrEmpty($response.automationVariableGuid)) {
            #Create Variable
            $body = @{
                name     = $Name;
                value    = $Value;
                secret   = $Secret;
                ItemType = 0;
            }    
            $body = ConvertTo-Json -InputObject $body -Depth 100

            $uri = ($script:PortalBaseUrl + "api/v1/automation/variable")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            $variableGuid = $response.automationVariableGuid

            Write-Information "Variable '$Name' created$(if ($script:debugLogging -eq $true) { ": " + $variableGuid })"
        } else {
            $variableGuid = $response.automationVariableGuid
            Write-Warning "Variable '$Name' already exists$(if ($script:debugLogging -eq $true) { ": " + $variableGuid })"
        }
    } catch {
        Write-Error "Variable '$Name', message: $_"
    }
}

function Invoke-HelloIDAutomationTask {
    param(
        [parameter(Mandatory)][String]$TaskName,
        [parameter(Mandatory)][String]$UseTemplate,
        [parameter(Mandatory)][String]$AutomationContainer,
        [parameter(Mandatory)][String][AllowEmptyString()]$Variables,
        [parameter(Mandatory)][String]$PowershellScript,
        [parameter()][String][AllowEmptyString()]$ObjectGuid,
        [parameter()][String][AllowEmptyString()]$ForceCreateTask,
        [parameter(Mandatory)][Ref]$returnObject
    )

    $TaskName = $TaskName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        $uri = ($script:PortalBaseUrl +"api/v1/automationtasks?search=$TaskName&container=$AutomationContainer")
        $responseRaw = (Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false) 
        $response = $responseRaw | Where-Object -filter {$_.name -eq $TaskName}

        if([string]::IsNullOrEmpty($response.automationTaskGuid) -or $ForceCreateTask -eq $true) {
            #Create Task

            $body = @{
                name                = $TaskName;
                useTemplate         = $UseTemplate;
                powerShellScript    = $PowershellScript;
                automationContainer = $AutomationContainer;
                objectGuid          = $ObjectGuid;
                variables           = (ConvertFrom-Json-WithEmptyArray($Variables));
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100

            $uri = ($script:PortalBaseUrl +"api/v1/automationtasks/powershell")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            $taskGuid = $response.automationTaskGuid

            Write-Information "Powershell task '$TaskName' created$(if ($script:debugLogging -eq $true) { ": " + $taskGuid })"
        } else {
            #Get TaskGUID
            $taskGuid = $response.automationTaskGuid
            Write-Warning "Powershell task '$TaskName' already exists$(if ($script:debugLogging -eq $true) { ": " + $taskGuid })"
        }
    } catch {
        Write-Error "Powershell task '$TaskName', message: $_"
    }

    $returnObject.Value = $taskGuid
}

function Invoke-HelloIDDatasource {
    param(
        [parameter(Mandatory)][String]$DatasourceName,
        [parameter(Mandatory)][String]$DatasourceType,
        [parameter(Mandatory)][String][AllowEmptyString()]$DatasourceModel,
        [parameter()][String][AllowEmptyString()]$DatasourceStaticValue,
        [parameter()][String][AllowEmptyString()]$DatasourcePsScript,        
        [parameter()][String][AllowEmptyString()]$DatasourceInput,
        [parameter()][String][AllowEmptyString()]$AutomationTaskGuid,
        [parameter()][String][AllowEmptyString()]$DatasourceRunInCloud,
        [parameter(Mandatory)][Ref]$returnObject
    )

    $DatasourceName = $DatasourceName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    $datasourceTypeName = switch($DatasourceType) { 
        "1" { "Native data source"; break} 
        "2" { "Static data source"; break} 
        "3" { "Task data source"; break} 
        "4" { "Powershell data source"; break}
    }

    try {
        $uri = ($script:PortalBaseUrl +"api/v1/datasource/named/$DatasourceName")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
    
        if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
            #Create DataSource
            $body = @{
                name               = $DatasourceName;
                type               = $DatasourceType;
                model              = (ConvertFrom-Json-WithEmptyArray($DatasourceModel));
                automationTaskGUID = $AutomationTaskGuid;
                value              = (ConvertFrom-Json-WithEmptyArray($DatasourceStaticValue));
                script             = $DatasourcePsScript;
                input              = (ConvertFrom-Json-WithEmptyArray($DatasourceInput));
                runInCloud         = $DatasourceRunInCloud;
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100
    
            $uri = ($script:PortalBaseUrl +"api/v1/datasource")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            
            $datasourceGuid = $response.dataSourceGUID
            Write-Information "$datasourceTypeName '$DatasourceName' created$(if ($script:debugLogging -eq $true) { ": " + $datasourceGuid })"
        } else {
            #Get DatasourceGUID
            $datasourceGuid = $response.dataSourceGUID
            Write-Warning "$datasourceTypeName '$DatasourceName' already exists$(if ($script:debugLogging -eq $true) { ": " + $datasourceGuid })"
        }
    } catch {
        Write-Error "$datasourceTypeName '$DatasourceName', message: $_"
    }

    $returnObject.Value = $datasourceGuid
}

function Invoke-HelloIDDynamicForm {
    param(
        [parameter(Mandatory)][String]$FormName,
        [parameter(Mandatory)][String]$FormSchema,
        [parameter(Mandatory)][Ref]$returnObject
    )

    $FormName = $FormName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/forms/$FormName")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        } catch {
            $response = $null
        }

        if(([string]::IsNullOrEmpty($response.dynamicFormGUID)) -or ($response.isUpdated -eq $true)) {
            #Create Dynamic form
            $body = @{
                Name       = $FormName;
                FormSchema = (ConvertFrom-Json-WithEmptyArray($FormSchema));
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100

            $uri = ($script:PortalBaseUrl +"api/v1/forms")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body

            $formGuid = $response.dynamicFormGUID
            Write-Information "Dynamic form '$formName' created$(if ($script:debugLogging -eq $true) { ": " + $formGuid })"
        } else {
            $formGuid = $response.dynamicFormGUID
            Write-Warning "Dynamic form '$FormName' already exists$(if ($script:debugLogging -eq $true) { ": " + $formGuid })"
        }
    } catch {
        Write-Error "Dynamic form '$FormName', message: $_"
    }

    $returnObject.Value = $formGuid
}


function Invoke-HelloIDDelegatedForm {
    param(
        [parameter(Mandatory)][String]$DelegatedFormName,
        [parameter(Mandatory)][String]$DynamicFormGuid,
        [parameter()][Array][AllowEmptyString()]$AccessGroups,
        [parameter()][String][AllowEmptyString()]$Categories,
        [parameter(Mandatory)][String]$UseFaIcon,
        [parameter()][String][AllowEmptyString()]$FaIcon,
        [parameter()][String][AllowEmptyString()]$task,
        [parameter(Mandatory)][Ref]$returnObject
    )
    $delegatedFormCreated = $false
    $DelegatedFormName = $DelegatedFormName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms/$DelegatedFormName")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        } catch {
            $response = $null
        }

        if([string]::IsNullOrEmpty($response.delegatedFormGUID)) {
            #Create DelegatedForm
            $body = @{
                name            = $DelegatedFormName;
                dynamicFormGUID = $DynamicFormGuid;
                isEnabled       = "True";
                useFaIcon       = $UseFaIcon;
                faIcon          = $FaIcon;
                task            = ConvertFrom-Json -inputObject $task;
            }
            if(-not[String]::IsNullOrEmpty($AccessGroups)) { 
                $body += @{
                    accessGroups    = (ConvertFrom-Json-WithEmptyArray($AccessGroups));
                }
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100

            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body

            $delegatedFormGuid = $response.delegatedFormGUID
            Write-Information "Delegated form '$DelegatedFormName' created$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormGuid })"
            $delegatedFormCreated = $true

            $bodyCategories = $Categories
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms/$delegatedFormGuid/categories")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $bodyCategories
            Write-Information "Delegated form '$DelegatedFormName' updated with categories"
        } else {
            #Get delegatedFormGUID
            $delegatedFormGuid = $response.delegatedFormGUID
            Write-Warning "Delegated form '$DelegatedFormName' already exists$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormGuid })"
        }
    } catch {
        Write-Error "Delegated form '$DelegatedFormName', message: $_"
    }

    $returnObject.value.guid = $delegatedFormGuid
    $returnObject.value.created = $delegatedFormCreated
}

<# Begin: HelloID Global Variables #>
foreach ($item in $globalHelloIDVariables) {
	Invoke-HelloIDGlobalVariable -Name $item.name -Value $item.value -Secret $item.secret 
}
<# End: HelloID Global Variables #>


<# Begin: HelloID Data sources #>
<# Begin: DataSource "AD - Account - Move OU | AD-Get-OUs" #>
$tmpPsScript = @'
# Variables configured in datasource
$selectedUser = $datasource.selectedUser
$searchOus = $ADUsersMoveOU -split ';'

# Global variables
# Outcommented as these are set from Global Variables
# $ADServer = "" # Optional, if not set the default domain controller is used

# Fixed values
$searchScope = "Subtree" # Options: Base, OneLevel, Subtree

$propertiesToSelect = @(
    "ObjectGuid",
    "Name",
    "DistinguishedName",
    "CanonicalName"
) # Properties to select from Microsoft AD, comma separated

# Set debug logging
$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

try {
    # Get the current user with DistinguishedName to extract current OU
    $actionMessage = "querying AD user [$($selectedUser.UserPrincipalName)] to get current OU"
    
    $getADUserSplatParams = @{
        Filter      = "ObjectGuid -eq '$($selectedUser.ObjectGuid)'"
        Properties  = @("DistinguishedName")
        Verbose     = $false
        ErrorAction = "Stop"
    }
    
    # Add server parameter if specified
    if (-not [string]::IsNullOrEmpty($ADServer)) {
        $getADUserSplatParams['Server'] = $ADServer
    }
    
    $adUser = Get-ADUser @getADUserSplatParams
    
    if ($null -ne $adUser) {
        # Extract OU from user's DistinguishedName
        # Example DN: CN=Calker\, Raymond,OU=Actief,OU=Users,DC=domain,DC=com
        # We want: OU=Actief,OU=Users,DC=domain,DC=com
        # Use lookahead to find the comma before OU= (handles escaped commas in CN)
        $userDN = $adUser.DistinguishedName
        $currentUserOU = $userDN -replace '^CN=.*?,(?=OU=)', ''
        Write-Information "Queried AD user [$($selectedUser.UserPrincipalName)]. Current OU: [$currentUserOU]"
    }
    else {
        Write-Information "Queried AD user [$($selectedUser.UserPrincipalName)]. Result: User not found in Active Directory"
        Write-Warning "Could not find user [$($selectedUser.UserPrincipalName)] in Active Directory"
        $currentUserOU = $null
    }

    # Build filter for OUs
    # Warning! When no searchValue is specified, all OUs will be retrieved
    if (-not $searchOus -or $searchOus -eq "*" -or $searchOus.Count -eq 0) {
        $filter = "*"
    }
    else {
        # Build a filter that matches any of the specified OU names
        $filterParts = @()
        foreach ($ouName in $searchOus) {
            $ouName = $ouName.Trim()
            if ($ouName) {
                $filterParts += "(DistinguishedName -eq '$ouName')"
            }
        }
        if ($filterParts.Count -gt 0) {
            $filter = $filterParts -join " -or "
        }
        else {
            $filter = "*"
        }
    }

    # Get AD Organizational Units
    # Microsoft docs: https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adorganizationalunit?view=windowsserver2025-ps
    $actionMessage = "querying AD OUs with filter [$filter]"

    $getADOUsSplatParams = @{
        Filter      = $filter
        Properties  = $propertiesToSelect
        SearchScope = $searchScope
        Verbose     = $false
        ErrorAction = "Stop"
    }
    
    # Add server parameter if specified
    if (-not [string]::IsNullOrEmpty($ADServer)) {
        $getADOUsSplatParams['Server'] = $ADServer
    }

    $adOUs = Get-ADOrganizationalUnit @getADOUsSplatParams | Select-Object -Property $propertiesToSelect

    Write-Information "Queried AD OUs that match filter [$filter]. Result count: $(($adOUs | Measure-Object).Count)"

    # Send results to HelloID
    if (($adOUs | Measure-Object).Count -gt 0) {
        # First, output the current user's OU (if found and in the list)
        if (-not [string]::IsNullOrEmpty($currentUserOU)) {
            $currentOU = $adOUs | Where-Object { $_.DistinguishedName -eq $currentUserOU }
            if ($null -ne $currentOU) {
                # Add DisplayValue property with (current) indicator
                $displayValue = "$($currentOU.DistinguishedName) (current)"
                $currentOU | Add-Member -MemberType NoteProperty -Name "DisplayValue" -Value $displayValue -Force
                
                Write-Verbose "Outputting current user OU first: [$($currentOU.DistinguishedName)]"
                Write-Output $currentOU
                
                # Then output all other OUs (excluding the current one)
                $otherOUs = $adOUs | Where-Object { $_.DistinguishedName -ne $currentUserOU }
                foreach ($adOU in $otherOUs) {
                    # Add DisplayValue property without (current) indicator
                    $adOU | Add-Member -MemberType NoteProperty -Name "DisplayValue" -Value $adOU.DistinguishedName -Force
                    Write-Output $adOU
                }
            }
            else {
                # Current OU not in the filtered list, output all OUs
                Write-Warning "Current user OU [$currentUserOU] not found in filtered results, outputting all OUs"
                foreach ($adOU in $adOUs) {
                    # Add DisplayValue property without (current) indicator
                    $adOU | Add-Member -MemberType NoteProperty -Name "DisplayValue" -Value $adOU.DistinguishedName -Force
                    Write-Output $adOU
                }
            }
        }
        else {
            # No current OU found, output all OUs
            Write-Warning "No current user OU found, outputting all OUs"
            foreach ($adOU in $adOUs) {
                # Add DisplayValue property without (current) indicator
                $adOU | Add-Member -MemberType NoteProperty -Name "DisplayValue" -Value $adOU.DistinguishedName -Force
                Write-Output $adOU
            }
        }
    }
}
catch {
    $ex = $PSItem
    $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
    $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

    Write-Warning $warningMessage
    Write-Error $auditMessage
}

'@ 
$tmpModel = @'
[{"key":"ObjectGuid","type":0},{"key":"Name","type":0},{"key":"DistinguishedName","type":0},{"key":"CanonicalName","type":0},{"key":"DisplayValue","type":0}]
'@ 
$tmpInput = @'
[{"description":null,"translateDescription":false,"inputFieldType":1,"key":"selectedUser","type":0,"options":1}]
'@ 
$dataSourceGuid_1 = [PSCustomObject]@{} 
$dataSourceGuid_1_Name = @'
AD - Account - Move OU | AD-Get-OUs
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_1_Name -DatasourceType "4" -DatasourceInput $tmpInput -DatasourcePsScript $tmpPsScript -DatasourceModel $tmpModel -DataSourceRunInCloud "False" -returnObject ([Ref]$dataSourceGuid_1) 
<# End: DataSource "AD - Account - Move OU | AD-Get-OUs" #>

<# Begin: DataSource "AD - Account - Move OU | AD-Get-Users-Wildcard-Name-DisplayName-UPN-Mail" #>
$tmpPsScript = @'
# Variables configured in form
$searchValue = $dataSource.searchValue
if ($searchValue -eq "*") {
    $filter = "Name -like '*'"
}
else {
    $filter = "Name -like '*$searchValue*' -or DisplayName -like '*$searchValue*' -or userPrincipalName -like '*$searchValue*' -or mail -like '*$searchValue*'"
}

# Global variables
$searchOUs = $ADUsersMoveSearchOU

# Fixed values
$propertiesToSelect = @(
    "ObjectGuid",
    "SamAccountName",
    "DisplayName",
    "UserPrincipalName",
    "DistinguishedName"
) # Properties to select from Microsoft AD, comma separated

# Set debug logging
$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

try {
    #region Searching user
    $actionMessage = "querying AD account(s) matching the filter [$filter] in OU(s) [$($searchOUs)]"

    $ous = $searchOUs -split ';'
    $adUsers = [System.Collections.ArrayList]@()
    foreach ($ou in $ous) {
        $actionMessage = "querying AD account(s) matching the filter [$filter] in OU [$($ou)]"
        $getAdUsersSplatParams = @{
            Filter      = $filter
            Searchbase  = $ou
            Properties  = $propertiesToSelect
            Verbose     = $False
            ErrorAction = "Stop"
        }
        $getAdUsersResponse = Get-AdUser @getAdUsersSplatParams | Select-Object -Property $propertiesToSelect

        if ($getAdUsersResponse -is [array]) {
            [void]$adUsers.AddRange($getAdUsersResponse)
        }
        else {
            [void]$adUsers.Add($getAdUsersResponse)
        }
    }
    Write-Information "Queried AD account(s) matching the filter [$filter] in OU(s) [$($searchOUs)]. Result count: $(($adUsers | Measure-Object).Count)"

    # Sort and Send results to HelloID (with OU property added)
    $actionMessage = "sending results to HelloID"
    $adUsers | Sort-Object -Property DisplayName | ForEach-Object {
        # Extract OU from user's DistinguishedName
        # Example DN: CN=Doe\, John,OU=Active,OU=Users,DC=domain,DC=com
        # We want: OU=Active,OU=Users,DC=domain,DC=com
        # Use lookahead to find the comma before OU= (handles escaped commas in CN)
        $userOU = $_.DistinguishedName -replace '^CN=.*?,(?=OU=)', ''
        
        # Add OrganizationalUnit property to the user object
        $_ | Add-Member -MemberType NoteProperty -Name "OrganizationalUnit" -Value $userOU -Force
        
        Write-Output $_
    } 
}
catch {
    $ex = $PSItem
    Write-Warning "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    Write-Error "Error $($actionMessage). Error: $($ex.Exception.Message)"
    # exit # use when using multiple try/catch and the script must stop
}

'@ 
$tmpModel = @'
[{"key":"ObjectGuid","type":0},{"key":"SamAccountName","type":0},{"key":"DisplayName","type":0},{"key":"UserPrincipalName","type":0},{"key":"DistinguishedName","type":0},{"key":"OrganizationalUnit","type":0}]
'@ 
$tmpInput = @'
[{"description":null,"translateDescription":false,"inputFieldType":1,"key":"searchValue","type":0,"options":1}]
'@ 
$dataSourceGuid_0 = [PSCustomObject]@{} 
$dataSourceGuid_0_Name = @'
AD - Account - Move OU | AD-Get-Users-Wildcard-Name-DisplayName-UPN-Mail
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_0_Name -DatasourceType "4" -DatasourceInput $tmpInput -DatasourcePsScript $tmpPsScript -DatasourceModel $tmpModel -DataSourceRunInCloud "False" -returnObject ([Ref]$dataSourceGuid_0) 
<# End: DataSource "AD - Account - Move OU | AD-Get-Users-Wildcard-Name-DisplayName-UPN-Mail" #>
<# End: HelloID Data sources #>

<# Begin: Dynamic Form "AD - Account - Move OU" #>
$tmpSchema = @"
[{"label":"Select user","fields":[{"key":"searchValue","templateOptions":{"label":"Search (wildcard search in Name, Display name, UserPrincipalName and Mail)","placeholder":"Name, Display name, UserPrincipalName or Mail (use * to search all users)","required":true,"minLength":1},"type":"input","summaryVisibility":"Hide element","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"gridUsers","templateOptions":{"label":"Select user","required":true,"grid":{"columns":[{"headerName":"Display Name","field":"DisplayName"},{"headerName":"User Principal Name","field":"UserPrincipalName"},{"headerName":"Organizational Unit","field":"OrganizationalUnit"}],"height":300,"rowSelection":"single"},"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_0","input":{"propertyInputs":[{"propertyName":"searchValue","otherFieldValue":{"otherFieldKey":"searchValue"}}]}},"useFilter":true,"allowCsvDownload":true},"type":"grid","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":true}]},{"label":"Move user","fields":[{"key":"currentOU","templateOptions":{"label":"Current OU","readonly":true,"useDependOn":true,"dependOn":"gridUsers","dependOnProperty":"OrganizationalUnit"},"type":"input","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"ou","templateOptions":{"label":"OU","required":true,"useObjects":false,"useDataSource":true,"useFilter":true,"options":["Option 1","Option 2","Option 3"],"valueField":"ObjectGuid","textField":"DisplayValue","dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_1","input":{"propertyInputs":[{"propertyName":"selectedUser","otherFieldValue":{"otherFieldKey":"gridUsers"}}]}},"defaultSelectorProperty":"ObjectGuid","useDefault":true},"hideExpression":"!model[\"gridUsers\"]","type":"dropdown","summaryVisibility":"Show","textOrLabel":"text","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false}]}]
"@ 

$dynamicFormGuid = [PSCustomObject]@{} 
$dynamicFormName = @'
AD - Account - Move OU
'@ 
Invoke-HelloIDDynamicForm -FormName $dynamicFormName -FormSchema $tmpSchema  -returnObject ([Ref]$dynamicFormGuid) 
<# END: Dynamic Form #>

<# Begin: Delegated Form Access Groups and Categories #>
$delegatedFormAccessGroupGuids = @()
if(-not[String]::IsNullOrEmpty($delegatedFormAccessGroupNames)){
    foreach($group in $delegatedFormAccessGroupNames) {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/groups/$group")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
            $delegatedFormAccessGroupGuid = $response.groupGuid
            $delegatedFormAccessGroupGuids += $delegatedFormAccessGroupGuid
        
            Write-Information "HelloID (access)group '$group' successfully found$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormAccessGroupGuid })"
        } catch {
            Write-Error "HelloID (access)group '$group', message: $_"
        }
    }
    if($null -ne $delegatedFormAccessGroupGuids){
        $delegatedFormAccessGroupGuids = ($delegatedFormAccessGroupGuids | Select-Object -Unique | ConvertTo-Json -Depth 100 -Compress)
    }
}

$delegatedFormCategoryGuids = @()
foreach($category in $delegatedFormCategories) {
    try {
        $uri = ($script:PortalBaseUrl +"api/v1/delegatedformcategories/$category")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        $response = $response | Where-Object {$_.name.en -eq $category}
    
        $tmpGuid = $response.delegatedFormCategoryGuid
        $delegatedFormCategoryGuids += $tmpGuid
    
        Write-Information "HelloID Delegated Form category '$category' successfully found$(if ($script:debugLogging -eq $true) { ": " + $tmpGuid })"
    } catch {
        Write-Warning "HelloID Delegated Form category '$category' not found"
        $body = @{
            name = @{"en" = $category};
        }
        $body = ConvertTo-Json -InputObject $body -Depth 100

        $uri = ($script:PortalBaseUrl +"api/v1/delegatedformcategories")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
        $tmpGuid = $response.delegatedFormCategoryGuid
        $delegatedFormCategoryGuids += $tmpGuid

        Write-Information "HelloID Delegated Form category '$category' successfully created$(if ($script:debugLogging -eq $true) { ": " + $tmpGuid })"
    }
}
$delegatedFormCategoryGuids = (ConvertTo-Json -InputObject $delegatedFormCategoryGuids -Depth 100 -Compress)
<# End: Delegated Form Access Groups and Categories #>

<# Begin: Delegated Form #>
$delegatedFormRef = [PSCustomObject]@{guid = $null; created = $null} 
$delegatedFormName = @'
AD - Account - Move OU
'@
$tmpTask = @'
{"name":"AD - Account - Move OU","script":"# variables configured in form:\r\n$user = $form.gridUsers\r\n$targetOU = $form.ou.DistinguishedName\r\n\r\n# Set debug logging\r\n$VerbosePreference = \"SilentlyContinue\"\r\n$InformationPreference = \"Continue\"\r\n$WarningPreference = \"Continue\"\r\n\r\n# Set TLS to accept TLS, TLS 1.1 and TLS 1.2\r\n[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12\r\n\r\ntry {\r\n    $actionMessage = \"moving AD account for user [$($user.UserPrincipalName)] with objectguid [$($user.ObjectGuid)] to OU [$targetOU]\"\r\n\r\n    $splatMoveADObjectParams = @{\r\n        Identity   = $user.ObjectGuid\r\n        TargetPath = $targetOU\r\n    }\r\n    \r\n    $null = Move-ADObject @splatMoveADObjectParams\r\n    \r\n    $Log = @{\r\n        Action            = \"MoveAccount\" # optional. ENUM (undefined = default) \r\n        System            = \"ActiveDirectory\" # optional (free format text) \r\n        Message           = \"Successfully moved AD account for user [$($user.UserPrincipalName)] with objectguid [$($user.ObjectGuid)] from OU [$($user.OrganizationalUnit)] to OU [$targetOU]\" # required (free format text) \r\n        IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n        TargetDisplayName = $user.UserPrincipalName # optional (free format text) \r\n        TargetIdentifier  = $user.ObjectGuid # optional (free format text) \r\n    }\r\n    #send result back  \r\n    Write-Information -Tags \"Audit\" -MessageData $log    \r\n}\r\ncatch {\r\n    $ex = $PSItem\r\n    $auditMessage = \"Error $($actionMessage). Error: $($ex.Exception.Message)\"\r\n    $warningMessage = \"Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)\"    \r\n\r\n    $Log = @{\r\n        Action            = \"MoveAccount\" # optional. ENUM (undefined = default) \r\n        System            = \"ActiveDirectory\" # optional (free format text) \r\n        Message           = \"Error $($actionMessage). Error Message: $auditMessage\" # required (free format text) \r\n        IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n        TargetDisplayName = $user.UserPrincipalName # optional (free format text) \r\n        TargetIdentifier  = $user.ObjectGuid # optional (free format text) \r\n    }\r\n    #send result back  \r\n    Write-Information -Tags \"Audit\" -MessageData $log      \r\n    Write-Warning $warningMessage   \r\n    Write-Error $auditMessage\r\n}","runInCloud":false}
'@ 

Invoke-HelloIDDelegatedForm -DelegatedFormName $delegatedFormName -DynamicFormGuid $dynamicFormGuid -AccessGroups $delegatedFormAccessGroupGuids -Categories $delegatedFormCategoryGuids -UseFaIcon "True" -FaIcon "fa fa-arrows-h" -task $tmpTask -returnObject ([Ref]$delegatedFormRef) 
<# End: Delegated Form #>

