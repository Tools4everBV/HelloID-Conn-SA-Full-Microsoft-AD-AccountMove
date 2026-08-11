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

