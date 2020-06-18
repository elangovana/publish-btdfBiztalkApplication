# Publish-BTDFBiztalkApplication
Powershell module to deploy biztalk applications created using BTDF

## Description
This script deploys a biztalk MSI built using BTDF, through standard BTDF steps as follows

- Takes a backup of the existing version of biztalk app, if any, MSI and bindings into a specified backup dir
- Undeploys the existing version, if any, of biztalk app
- Uninstalls existing version of biztalk app, if any
- Installs the new version of biztalk MSI created using BTDF
- Deploys the new installed version of biztalk using BTDF

Please refer to the wiki for details on how to use this module. There's also a section on how to use it for Octopus Deploy.

## Contributing
- For BizTalk 2016 and 2020, send Pull Requests to this repository.
- BizTalk 2013 is not used by maintainers of this repository anymore.

## Feedback
- Open GitHub issues
- Ask at StackOverflow (but we don't listen for any related tags).

## Related projects
[BizTalk Deployment Framework (BTDF)](https://github.com/BTDF/DeploymentFramework)

## License
The MIT License (MIT)
Copyright (c) 2016 elangovana
