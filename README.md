# HelloID-Conn-SA-Full-AD-AccountMove

| :information_source: Information |
|:---|
| This repository contains the connector and configuration code only. The implementer is responsible for acquiring the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |

## Description
_HelloID-Conn-SA-Full-AD-AccountMove_ is a delegated form designed for use with HelloID Service Automation (SA). It can be imported into HelloID and customized according to your requirements.

By using this delegated form, you can move Active Directory user accounts to another organizational unit or container. The following options are available:
1. Search and select one or more Active Directory user accounts
2. Select the target Active Directory container
3. The selected accounts are moved to the configured target container

## Getting started

### Requirements

- **Active Directory Access**:
  The connector requires access to an Active Directory domain with sufficient permissions to search for users and move objects. A service account with appropriate AD permissions is necessary.

- **HelloID Agent**:
  A HelloID Agent must be installed and configured to communicate with the Active Directory domain.

- **PowerShell module 'ActiveDirectory'**:
  The HelloID Agent must have PowerShell available with Active Directory module support.

### Connection settings

The following user-defined variables are used by the connector.

| Setting         | Description                                                                                                      | Mandatory |
| --------------- | ---------------------------------------------------------------------------------------------------------------- | --------- |
| AdUsersSearchOu | Semicolon-separated `;` list of Active Directory OUs used to scope the user search results in the delegated form | Yes       |

## Remarks

### User Search

- **Search Functionality:** Users can search for accounts using a wildcard (`*`) to return all users within the specified OUs, or by entering partial text to search across Name, DisplayName, UserPrincipalName, and Mail attributes.

- **The search scope is limited to the OUs defined in the `AdUsersSearchOu` variable.** Configure this variable carefully to avoid exposing accounts outside the intended scope.

## Development resources

### PowerShell Module
This connector uses the ActiveDirectory PowerShell module for managing Active Directory user accounts and organizational units.

- [ActiveDirectory Module Documentation](https://learn.microsoft.com/en-us/powershell/module/activedirectory/)

### Cmdlets
The following PowerShell cmdlets are used by the connector:

| Cmdlet | Description |
| --- | --- |
| Get-ADUser | Retrieves Active Directory user accounts |
| Get-ADOrganizationalUnit | Retrieves Active Directory organizational units |
| Move-ADObject | Moves Active Directory objects to a different container |

### Cmdlet documentation
- [Get-ADUser](https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-aduser)
- [Get-ADOrganizationalUnit](https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adorganizationalunit)
- [Move-ADObject](https://learn.microsoft.com/en-us/powershell/module/activedirectory/move-adobject)

## Getting help

| :bulb: Tip |
|:---|
| For more information on Delegated Forms, please refer to our [documentation](https://docs.helloid.com/en/service-automation/delegated-forms.html) pages. |

## HelloID docs
The official HelloID documentation can be found at: [https://docs.helloid.com/](https://docs.helloid.com/)
