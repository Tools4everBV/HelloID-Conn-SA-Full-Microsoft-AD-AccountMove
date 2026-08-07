# variables configured in form
$ou = $form.ou.Path
$users = $form.gridUsers

# Set debug logging
$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

foreach ($user in $users) {
    try {
        $actionMessage = "moving AD account for user [$($user.userPrincipalName)] with objectguid [$($user.ObjectGuid)] to OU [$($ou)]"

        Move-ADObject -Identity $user.ObjectGuid -TargetPath $ou

        $Log = @{
            Action            = "MoveAccount" # optional. ENUM (undefined = default) 
            System            = "ActiveDirectory" # optional (free format text) 
            Message           = "Moved AD account for user [$($user.userPrincipalName)] with objectguid [$($user.ObjectGuid)] to OU [$($ou)]" # required (free format text) 
            IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
            TargetDisplayName = $user.userPrincipalName # optional (free format text) 
            TargetIdentifier  = $user.ObjectGuid # optional (free format text) 
        }
        Write-Information -Tags "Audit" -MessageData $log
    }
    catch {
        $ex = $PSItem
        $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
        $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    
        $log = @{
            Action            = "MoveAccount" # optional. ENUM (undefined = default) 
            System            = "ActiveDirectory" # optional (free format text) 
            Message           = $auditMessage # required (free format text) 
            IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
            TargetDisplayName = $user.userPrincipalName # optional (free format text) 
            TargetIdentifier  = $user.ObjectGuid # optional (free format text) 
        }
        Write-Information -Tags "Audit" -MessageData $log
        Write-Warning $warningMessage
        Write-Error $auditMessage
    }
}
