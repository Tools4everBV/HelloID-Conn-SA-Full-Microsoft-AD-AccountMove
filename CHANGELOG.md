# Change Log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com), and this project adheres to [Semantic Versioning](https://semver.org).

## [2.0.0] - 2026-08-11

### Changed
- Refactored all scripts to current HelloID best practices
- Updated dynamic form structure for improved user experience
- Enhanced error handling and audit logging in task script
- Improved user search with wildcard support across Name, DisplayName, UserPrincipalName, and Mail attributes

### Added
- New datasource for retrieving Active Directory organizational units
- Support for selecting target OU from dropdown
- Comprehensive audit logging with detailed success and error messages

### Removed
- Obsolete account type table generation datasource
- Legacy scripts with outdated patterns

## [1.0.1] - 2021-11-03

### Changed
- Added version number and updated all-in-one setup script

## [1.0.0] - 2020-09-01

### Added
- Initial release of AD Account Move delegated form