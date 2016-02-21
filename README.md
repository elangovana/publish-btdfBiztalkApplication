# Publish-BTDFBiztalkApplication
Powershell module to deploy biztalk applications created using BTDF

##Description
This script deploys a biztalk MSI built using BTDF, through standard BTDF steps as follows

- Takes a backup of the existing version of biztalk app, if any, MSI and bindings into a specified backup dir
   
- Undeploys the existing version, if any, of biztalk app
    
- Uninstalls existing version of biztalk app, if any
    
- Installs the new version of biztalk MSI created using BTDF
    
- Deploys the new installed version of biztalk using BTDF

This script was tested with Biztalk 2013 R2 and BTDF Release 5.6 (Release Candidate)




##EXAMPLE 1

    Import-Module .\Publish-BiztalkBtdfApplication.psm1 
    publish-btdfBiztalkApplication  -biztalkMsi "C:\mybtdfMsi.msi" -installdir "C:\program files\mybtdfMsi"  -biztalkApplicationName DeploymentFramework.Samples.BasicMasterBindings -BtdfProductName "Deployment Framework for BizTalk - BasicMasterBindings" -backupDir c:\mybackupdir -importIntoBiztalkMgmtDb 1 -deployOptions @{"/p:VDIR_USERNAME"="contoso\adam";"/p:VDIR_USERPASS"="@5t7sd";"/p:ENV_SETTINGS"="""c:\program files\mybtdfMsi\Deployment\PortBindings.xml"""} 


This installs BTDF Biztalk application MSI C:\mybtdfMsi.msi, into install directory C:\program files\mybtdfMsi. in this example, the custom deploy options,  VDIR_USERNAME, VDIR_USERPASS and ENV_SETTINGS are the only deployment options required to deploy the app.
 
Note how the value of one of the BTDF deploy options, "/p:ENV_SETTINGS", is double quoted twice """c:\program files\mybtdfMsi\Deployment\PortBindings.xml""". Please make sure values with spaces are double quoted twice in the deploy, undeploy and install options hastable
    

##EXAMPLE 2
To run this script with the awesome whatif switch

        publish-btdfBiztalkApplication -whatif
  
##EXAMPLE 3
To run this script with increased log level for troublehooting, use the verbose switch

        publish-btdfBiztalkApplication -verbose
