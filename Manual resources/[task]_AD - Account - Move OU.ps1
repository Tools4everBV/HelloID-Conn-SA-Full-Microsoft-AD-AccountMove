# variables configured in form:
$user = $form.gridUsers
$targetOU = $form.ou.DistinguishedName

# Set debug logging
$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

try {
    $actionMessage = "moving AD account for user [$($user.UserPrincipalName)] with objectguid [$($user.ObjectGuid)] to OU [$targetOU]"

    $splatMoveADObjectParams = @{
        Identity   = $user.ObjectGuid
        TargetPath = $targetOU
    }
    
    $null = Move-ADObject @splatMoveADObjectParams
    
    $Log = @{
        Action            = "MoveAccount" # optional. ENUM (undefined = default) 
        System            = "ActiveDirectory" # optional (free format text) 
        Message           = "Successfully moved AD account for user [$($user.UserPrincipalName)] with objectguid [$($user.ObjectGuid)] from OU [$($user.OrganizationalUnit)] to OU [$targetOU]" # required (free format text) 
        IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
        TargetDisplayName = $user.UserPrincipalName # optional (free format text) 
        TargetIdentifier  = $user.ObjectGuid # optional (free format text) 
    }
    #send result back  
    Write-Information -Tags "Audit" -MessageData $log    
}
catch {
    $ex = $PSItem
    $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
    $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"    

    $Log = @{
        Action            = "MoveAccount" # optional. ENUM (undefined = default) 
        System            = "ActiveDirectory" # optional (free format text) 
        Message           = "Error $($actionMessage). Error Message: $auditMessage" # required (free format text) 
        IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
        TargetDisplayName = $user.UserPrincipalName # optional (free format text) 
        TargetIdentifier  = $user.ObjectGuid # optional (free format text) 
    }
    #send result back  
    Write-Information -Tags "Audit" -MessageData $log      
    Write-Warning $warningMessage   
    Write-Error $auditMessage
}
