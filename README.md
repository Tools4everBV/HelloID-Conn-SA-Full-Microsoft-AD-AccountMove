## HelloID-Conn-SA-Full-AD-AccountMove

| :information_source: Information |
| :------------------------------- |
| This repository contains the connector and configuration code only. The implementer is responsible for acquiring the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |

## Description
_HelloID-Conn-SA-Full-AD-AccountMove_ is a delegated form for use with HelloID Service Automation (SA). It can be imported into HelloID and customized according to your requirements.

By using this delegated form, you can move Active Directory user accounts to another organizational unit or container. The following options are available:
1. Search and select one or more Active Directory user accounts
2. Select the target Active Directory container
3. The selected accounts are moved to the configured target container

## Getting started
### Requirements

- **HelloID Agent**:<br>
  A HelloID Agent must be installed and configured to communicate with the Active Directory domain.
- **Active Directory PowerShell module**:<br>
  The host executing the scripts must have the Active Directory module available so `Get-ADUser` and `Move-ADObject` can be used.
- **Permissions to read and move AD objects**:<br>
  The service account used to run the form must be allowed to search for users and move objects to the target OUs.

### Connection settings

The following user-defined variables are used by the connector.

| Setting         | Description                                                                                                      | Mandatory |
| --------------- | ---------------------------------------------------------------------------------------------------------------- | --------- |
| AdUsersSearchOu | Semicolon-separated `;` list of Active Directory OUs used to scope the user search results in the delegated form | Yes       |

## Remarks

### Search Scope Is Controlled By AdUsersSearchOu
- **Scoped user search**: The user search data source only returns accounts found in the OUs configured in `AdUsersSearchOu`. Configure this variable carefully to avoid exposing accounts outside the intended scope.

## Development resources

### API endpoints

The following interfaces are used by the connector.

| Endpoint / Interface                         | Description                                                                   |
| -------------------------------------------- | ----------------------------------------------------------------------------- |
| Active Directory PowerShell: `Get-ADUser`    | Retrieves matching user accounts and validates selected accounts              |
| Active Directory PowerShell: `Move-ADObject` | Moves the selected account to the target OU or container                      |

### API documentation

- Microsoft Active Directory PowerShell module: https://learn.microsoft.com/powershell/module/activedirectory/

## Getting help
> :bulb: **Tip:**  
> _For more information on Delegated Forms, please refer to our [documentation](https://docs.helloid.com/en/service-automation/delegated-forms.html) pages_.

## HelloID docs
The official HelloID documentation can be found at: https://docs.helloid.com/
