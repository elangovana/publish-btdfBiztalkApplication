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




##EXAMPLE 1 - Get started

    Import-Module .\Publish-BiztalkBtdfApplication.psm1 
    publish-btdfBiztalkApplication  -biztalkMsi "C:\mybtdfMsi.msi" -installdir "C:\program files\mybtdfMsi"  -biztalkApplicationName DeploymentFramework.Samples.BasicMasterBindings -BtdfProductName "Deployment Framework for BizTalk - BasicMasterBindings" -backupDir c:\mybackupdir -importIntoBiztalkMgmtDb 1 -deployOptions @{"/p:VDIR_USERNAME"="contoso\adam";"/p:VDIR_USERPASS"="@5t7sd";"/p:ENV_SETTINGS"="""c:\program files\mybtdfMsi\Deployment\PortBindings.xml"""} 


This installs BTDF Biztalk application MSI C:\mybtdfMsi.msi, into install directory C:\program files\mybtdfMsi. in this example, the custom deploy options,  VDIR_USERNAME, VDIR_USERPASS and ENV_SETTINGS are the only deployment options required to deploy the app.
 
Note how the value of one of the BTDF deploy options, "/p:ENV_SETTINGS", is double quoted twice """c:\program files\mybtdfMsi\Deployment\PortBindings.xml""". Please make sure values with spaces are double quoted twice in the deploy, undeploy and install options hastable
    

##EXAMPLE 2 - Whatif switch
To run this script with the awesome whatif switch

        publish-btdfBiztalkApplication -whatif
  
##EXAMPLE 3 - Increase logging
To run this script with increased log level for troublehooting, use the verbose switch

        publish-btdfBiztalkApplication -verbose

##EXAMPLE 4 - Customise Msbuild and BtsTask paths
Customises the paths of msbuild and btstask 

         publish-btdfBiztalkApplication  -msbuildPath "C:\Program Files (x86)\MSBuild\12.0\Bin\msbuild.exe" -btsTaskPath "$env:systemdrive\Program Files (x86)\Microsoft BizTalk Server 2013 R2\BtsTask.exe"

##EXAMPLE 5 - Octopus Deploy
Step 1: Download this module and import into octopus deploy as shown in http://docs.octopusdeploy.com/display/OD/Script+Modules
 

Step 2: Script - Sample application deployment

      #Import-Module .\Publish-BiztalkBtdfApplication.psm1 -Force
      ##Get MSI from nuget package. 
      $installDir=$OctopusParameters['Octopus.Action[Get Biztalk Package].Output.Package.InstallationDirectoryPath']
       
      ##This assumes you have created a nuget package with the msi and the msi is under content dir when the nuget package is unpacked
      $Msi= get-item "$(Join-path $installDir "content\DeploymentFramework.Samples.BasicMasterBindings-4.7.")*.msi"
      #$Msi="c:\temp\DeploymentFramework.Samples.BasicMasterBindings-1.0.0.msi"
       
      ##Octopus environment variables required for this deployment, 
      ##For non-clustered BizTalk server environments set this to true always
      #$IsFirstBiztalkServer = $true
      $IsFirstBiztalkServer = $OctopusParameters['Octopus.Tentacle.CurrentDeployment.TargetedRoles'] -contains "Biztalk Primary"
      $appPoolIdentity = $OctopusParameters['AppPoolIdentity']
      $appPoolPassword = $OctopusParameters['AppPoolPassword']
       
      ##initialise variables
      $backupDir = join-path  "c:\biztalk apps" "Backupdir"
      $biztalkAppName="DeploymentFramework.Samples.BasicMasterBinding"
      $btdfProductName=”Deployment Framework for BizTalk - BasicMasterBindings”
      $appInstallDir = join-path  "c:\biztalk apps" $btdfProductName
       
      ##If you have more options in your BTDF installwizard.xml, just add them  as name value pairs as shown here. 
      ##PS. The /p: is mandatory :
      ##Make sure the names or values with spaces are enclosed within double quotes. 
      ##Double quotes in PowerShell strings can be escaped using "" or `"
      ##In this example, see the value of /p:ENV_Settings is escaped with ""
      $deployOptions = @{"/p:VDIR_USERNAME"="$appPoolIdentity";
                      "/p:VDIR_USERPASS"="$appPoolPassword";
                      "/p:BTSACCOUNT"="biztalk";
                      "/p:ENV_SETTINGS"="""$appInstallDir\Deployment\EnvironmentSettings\PROD_settings.xml"""
      } 
       
      New-Item $backupDir -ItemType Container -Force 
       
      ##Publish using the powershell module.
      publish-btdfBiztalkApplication  -biztalkMsi $Msi  -installdir  $appInstallDir  -biztalkApplicationName $biztalkAppName -btdfProductName $btdfProductName -backupDir $backupDir -importIntoBiztalkMgmtDb  $IsFirstBiztalkServer  -deployOptions  $deployOptions 
       
       
      ##To see more options available to customise you deployment including custom undeploy options, set msbuild or BTS task paths use get-help 
      #get-help publish-BTDFBiztalkApplication –Detailed
      ##To troubleshoot and increase log level use the -Verbose switch
      #publish-BTDFBiztalkApplication –verbose


##EXAMPLE 6  - To see more details, get help!
         
         get-help publish-BTDFBiztalkApplication -full
         
