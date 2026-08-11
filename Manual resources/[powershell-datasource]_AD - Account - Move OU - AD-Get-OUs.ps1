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

