#requires -version 4
#Requires -RunAsAdministrator


<#
.SYNOPSIS
    Deploys biztalk applications created using Biztalk Deployment framework (BTDF)

.DESCRIPTION
    This script deploys a biztalk MSI built using BTDF, through standard BTDF steps as follows
        - Takes a backup of the existing version of biztalk app, if any, MSI and bindings into a specified backup dir
        - Undeploys the existing version, if any, of biztalk app
        - Uninstalls existing version of biztalk app, if any
        - Installs the new version of biztalk MSI created using BTDF
        - Deploys the new installed version of biztalk using BTDF

    This script was tested with Biztalk 2013 R2 and BTDF Release 5.6 (Release Candidate)

.INPUTS
    None

.OUTPUTS
    None


 .LINK
    https://biztalkdeployment.codeplex.com/
    https://biztalkdeployment.codeplex.com/releases/view/616874
    http://thoughtsofmarcus.blogspot.com.au/2010/10/find-all-possible-parameters-for-msi.html


.EXAMPLE 

    publish-btdfBiztalkApplication  -biztalkMsi "C:\mybtdfMsi.msi" -installdir "C:\program files\mybtdfMsi" -biztalkBtdfApp mybtdfMsi -backupDir c:\mybackupdir -importIntoBiztalkMgmtDb 1 -deployOptions @{"/p:VDIR_USERNAME"="contoso\adam";"/p:VDIR_USERPASS"="@5t7sd";"/p:ENV_SETTINGS"="""c:\program files\mybtdfMsi\Deployment\PortBindings.xml"""} 

    This installs BTDF Biztalk application MSI C:\mybtdfMsi.msi, into install directory C:\program files\mybtdfMsi. in this example, the custom deploy options,  VDIR_USERNAME, VDIR_USERPASS and ENV_SETTINGS are the only deployment options required to deploy the app.
 
    Note how the value of one of the BTDF deploy options, "/p:ENV_SETTINGS", is double quoted twice """c:\program files\mybtdfMsi\Deployment\PortBindings.xml""". Please make sure values with spaces are double quoted twice in the deploy, undeploy and install options hastable
    

.EXAMPLE 
     To run this script with the awesome whatif switch
    publish-btdfBiztalkApplication  -biztalkMsi "C:\mybtdfMsi.msi" -installdir "C:\program files\mybtdfMsi" -biztalkBtdfApp mybtdfMsi -backupDir c:\mybackupdir -importIntoBiztalkMgmtDb 1 -deployOptions @{"/p:ENV_SETTINGS"="""c:\program files\mybtdfMsi\Deployment\PortBindings.xml"""} -whatif
  


#>
function publish-btdfBiztalkApplication(){

[CmdletBinding(SupportsShouldProcess=$True)]
Param(
    # The path of biztalk MSI created using BTDF
    [Parameter(Mandatory=$True)]
    [string] $biztalkMsi, 

    # The directory into which the MSI needs to be installed
	[Parameter(Mandatory=$True)]
	[string]$installdir ,
    
    #The name of the biztalk application. This must match the name of the biztalk application the msi creates.
    [Parameter(Mandatory=$True)]
    [string] $biztalkBtdfApp, 


    #The backup directory into which an existing Biztalk application, if any, will be backed up to
    [Parameter(Mandatory=$True)]
    $backupDir,

    #This option is useful for deploying in clustered biztalk server environments. Set this to false when installing on all servers except the last one within the clustered environment. 
	[Parameter(Mandatory=$True)]
    [boolean] $importIntoBiztalkMgmtDb=$true,
   

    #This is a hash table of key-value pairs of deploy options that the BTDF deploy UI walks you through. This hash table of custom variables must contain all variables specified in the install.xml of your BTDF project, including the port bindings file.
    #At a bare minimum you will need to specify the port bindings file. Please makes sure that the values with spaces are quoted correctly, for further details see examples
    #Note: There is no need to specify the default variable BT_DEPLOY_MGMT_DB in here, as it is already captured as part of $importIntoBiztalkMgmtDb
    [Parameter(Mandatory=$True)]
    [hashtable]$deployOptions,

    #This is a hash table of key-value pairs of install options. This is the list of public properties available when installing an MSI. 
    [hashtable]$installOptions = $NULL,
    

    #This is a keyvalue pairs of deploy options. This is a list of key value pairs for all custom variables specified in the uninstall.xml of your BTDF project.
    #Note: There is no need to specify the default variable BT_DEPLOY_MGMT_DB in here, as it is already captured as part of $importIntoBiztalkMgmtDb 
    [hashtable]$undeployOptions = $NULL,

    #This is the BtsTaskPath. Please make sure the path is quoted correctly.
    [string]$btsTaskPath="$env:systemdrive\""Program Files (x86)""\""Microsoft BizTalk Server 2013 R2""\BtsTask.exe",

    #This is the msbuild path.
    [string]$msbuildPath = "$env:systemdrive\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe"
   

)

############################################
#############Main###########################

$ErrorActionPreference = "Stop"

$script:btsTaskPath = $btsTaskPath 

    try{
	   
    
        Write-Host Step 1: Udneploying existing biztalk app $BiztalkBtdfApp   
        undeploy-btdfBiztalkApp -btdfBiztalkAppName $BiztalkBtdfApp -isFirstBiztalkServer $ImportIntoBiztalkMgmtDb  -msbuildExePath $msbuildPath -backupdir $backupDir 

	    Write-Host Step 2: Uninstalling existing biztalk app $BiztalkBtdfApp   
        uninstall-btdfBiztalkApp $BiztalkBtdfApp  

	    Write-Host Step 3: Installing  biztalk msi $BiztalkMsi
        install-btdfBiztalkApp  $BiztalkMsi -installDir $installdir  -installOptions $installOptions

	    Write-Host Step 4: Deploying iztalk app $BiztalkBtdfApp   
        deploy-btdfBiztalkApp -btdfBiztalkAppName $BiztalkBtdfApp -isLastBiztalkServer $ImportIntoBiztalkMgmtDb -msbuildExePath $msbuildPath -deployOptionsNameValuePairs $deployOptions 
 
  
        Write-Host ------------------------------------------------------------------
        Write-Host Completed installing $BiztalkBtdfApp using MSI $BiztalkMsi

    }
    finally{

    }

}





function flatten-keyValues(){
Param(
    [hashtable]$hashMap = $null
    )
 
    $flattendMap = ""
    if ($hashMap -eq $null){
        return $flattendMap
    }

    foreach ($h in $hashMap.GetEnumerator()) {
            $flattendMap =  $flattendMap + " " + $($h.Name) + "=" + $($h.Value)
    }
    
  
    return $flattendMap
}

function Get-AppUninstallCommand(){
    param(
     [Parameter(Mandatory=$True)]
     [string]$appDisplayName
    )
    $app = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\** | Where-Object {
                    $_.DisplayName -like “$appDisplayName*”
        }

    if ($app -eq $null){
        $app = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\** | Where-Object {
                    $_.DisplayName -like “$appDisplayName*”
        }
    }
    
    if ($app -ne $null){
       return $app.uninstallstring

    }

    return $null
}

function get-btdfUndeployShortCut(){
    param([Parameter(Mandatory=$True)]
        [string]$btdfBiztalkAppName
    )
    #get BTDF shortcuts in the startmenu for the app, regardless of version
    $undeployAppBasePath = "$Env:SystemDrive\ProgramData\Microsoft\Windows\Start Menu\Programs\$btdfBiztalkAppName*\undeploy $btdfBiztalkAppName*.lnk"


    $undeployShortcut  = get-btdfShortCut  $undeployAppBasePath

    return $undeployShortcut 
}



function get-btdfDeployShortCut(){
    param([Parameter(Mandatory=$True)]
        [string]$btdfBiztalkAppName
    )
    #get BTDF shortcuts in the startmenu for the app, regardless of version
    $deployAppBasePath = "$Env:SystemDrive\ProgramData\Microsoft\Windows\Start Menu\Programs\$btdfBiztalkAppName*\deploy $btdfBiztalkAppName*.lnk"


    $deployShortcut  = get-btdfShortCut  $deployAppBasePath

    return $deployShortcut 
}

function get-btdfShortCut(){
    param([Parameter(Mandatory=$True)]
        [string]$shortcutSearchPath
    )
    
    #ensure there is exactly one match for the path, else appropriate error or warning
    $items = get-item  $shortcutSearchPath
      
    if ($items.count -gt 1){
        write-error "Multiple items matching $shortcutSearchPath found , $items. Unable to detemine which app needs to be managed!!"
    }
    elseif ($items.count -eq 0){
        write-warning "No items found using search path $shortcutSearchPath"
    }

    $undeployShortcut = $items[0]
    #Final check to makesure it is a file and not directory!!
    if (-not (test-path $undeployShortcut -PathType Leaf)){
        write-error "Expected shortcut to be a file, found a folder instead!!"
    }

    return $undeployShortcut 
}


function get-btdfProjectFileName(){	
    param([Parameter(Mandatory=$True)]
    [string]$btdfDeployOrUndeployShortcutFileName)

	if ( -not (Test-Path $btdfDeployOrUndeployShortcutFileName -PathType Leaf)){
		write-error "The file $btdfDeployOrUndeployShortcutFileName not found"
	}

    $shortcutObj = get-shortcutProperties $btdfDeployOrUndeployShortcutFileName
    
    $projectFileRegex="\s[^:]*\.btdfproj"

    if  ($shortcutObj.TargetArguments -match $projectFileRegex){
            $projectFile =([string] $matches[0]).Trim()
    }else{
        write-error "Could not find any project file matching regex $projectFileRegex in expression $shortcutObj.TargetArguments"
    }

	return $projectFile
}

function get-shortcutProperties(){
   param([Parameter(Mandatory=$True)]
    [string]$shortCut
    )
    $shell= $null

    try{
        $shell = New-Object -ComObject WScript.Shell
        $properties = @{
                            ShortcutName = $shortCut.Name
                            Target = $shell.CreateShortcut($shortCut).targetpath
                            StartIn = $shell.CreateShortcut($shortCut).WorkingDirectory
                            TargetArguments= $shell.CreateShortcut($shortCut).Arguments
                        }
        return New-Object PSObject -Property $Properties
    }
    finally{
        if ($shell -ne $null){
             [Runtime.InteropServices.Marshal]::ReleaseComObject($Shell) | Out-Null
        }
    }
    
    
}


function   install-btdfBiztalkApp(){
	
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [Parameter(Mandatory=$True)]
    [string]$BiztalkAppMSI,

    [Parameter(Mandatory=$True)]
    [string]$installDir,

    [hashtable]$installOptions =$null
    )

    $stdOutLog = [System.IO.Path]::GetTempFileName()
    $additionalInstallProperties = flatten-keyValues $installOptions
    try{
		 $args = @("/c msiexec /i ""$BiztalkAppMSI"" /q /lv  $stdOutLog INSTALLDIR=""$installDir"" $additionalInstallProperties ") 
         
		#what if check
		if ($pscmdlet.ShouldProcess("$env:computername", "cmd $args")){
				run-command "cmd" $args
		}
    }
    catch{
        
        $ErrorMessage = $_.Exception.Message
        $msiOutput = gc  $stdOutLog |  Out-String
        write-error " $ErrorMessage $msiOutput"

    }
   
    $msiOutput = gc  $stdOutLog |  Out-String
    write-host $msiOutput

}
    

function  deploy-btdfBiztalkApp(){

	[CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [Parameter(Mandatory=$True)]
    [string]$btdfBiztalkAppName,

	[Parameter(Mandatory=$True)]

	[boolean]$isLastBiztalkServer,
	
    [Parameter(Mandatory=$True)]
    [string]$msbuildExePath,

	[hashtable]$deployOptionsNameValuePairs =$null
    )

    Write-Host Deploying biztalk app $btdfBiztalkAppName .......
    try{
     
        $appUninstallCmd = Get-AppUninstallCommand $btdfBiztalkAppName

        
        #extra check for whatif, when running without any version of the biztalk app installed 
        if (-not($pscmdlet.ShouldProcess("$env:computername", "deploy-btdfBiztalkApp"))){
				  return
		}
           

        if ($appUninstallCmd -eq $null){
            write-error "No  version of  $btdfBiztalkAppName found. Please ensure this app is installed first"
          
        }
      
		$deployShortCut = get-btdfdeployShortcut $btdfBiztalkAppName
		write-host Found shortcut for deploying app $deployShortCut
		$projectFile = get-btdfProjectFileName  $deployShortCut
		$installStartInDir = $(get-shortcutProperties $deployShortCut).StartIn

        $addtionalDeployOptions = flatten-keyValues $deployOptionsNameValuePairs

        $stdErrorLog = [System.IO.Path]::GetTempFileName()
        $arg=@([System.String]::Format("/c @echo on & cd ""{0}"" & ""{1}"" /p:Interactive=False  /t:Deploy /clp:NoSummary /nologo   /tv:4.0 {2} /v:diag /p:DeployBizTalkMgmtDB={3} /p:Configuration=Server {4}",  $installStartInDir,$msbuildExePath, $projectFile, $isLastBiztalkServer, $addtionalDeployOptions))
       
		run-command "cmd" $arg
        
       
        
        Write-Host Application $btdfBiztalkAppName  Deployed 
    

    }
    finally{
         # do nothing
    }
}



function  undeploy-btdfBiztalkApp(){

	[CmdletBinding(SupportsShouldProcess=$true)]
    param(
   
    [Parameter(Mandatory=$True)]
    [string]$btdfBiztalkAppName,

    [Parameter(Mandatory=$True)]
	[boolean]$isFirstBiztalkServer,
	
    [Parameter(Mandatory=$True)]
    [string]$backupdir,

    [Parameter(Mandatory=$True)]
    [string]$msbuildExePath,

	[hashtable]$undeployOptionsNameValuePairs = $null

    
    )

    Write-Host Undeploying biztalk app $btdfBiztalkAppName .......
    try{

       #check if biztalk app exists, els do nothing and return
		if (-not(test-biztalkAppExists $btdfBiztalkAppName)){

			write-host "The application $btdfBiztalkAppName does not exist on the biztalk sever. Nothing to undeploy"
			return
         }

		#Take a backup of biztalk app before undeploying...
		backup-BiztalkApp $btdfBiztalkAppName $backupdir

		#Check if biztalk app can be undeployed using BTDF undeploy. If BTDF undeploy not found, undeploy using BTSTask.exe
		$appUninstallCmd = Get-AppUninstallCommand $btdfBiztalkAppName
        if ($appUninstallCmd -eq $null){
            write-host No older version of  $btdfBiztalkAppName found. Nothing to undeploy

			 #BTDF undeploy not found, undeploy using BTSTask.exe
            if (test-biztalkAppExists $btdfBiztalkAppName){
                write-warning "No Btdf command to undeploy exists. Using Bts task to remove app"
                Remove-BiztalkApp $btdfBiztalkAppName
            }
            return
        }
		
        
        #undeploy using btdf undeploy  		
		$undeployShortCut = get-btdfUndeployShortcut $btdfBiztalkAppName
		write-host Found shortcut for undeploying app $undeployShortCut
        $installDirStartIn = $(get-shortcutProperties $undeployShortCut).StartIn
		$projectFile = get-btdfProjectFileName  $undeployShortCut
		

        $addtionalunDeployOptions = flatten-keyValues $undeployOptionsNameValuePairs

        $stdErrorLog = [System.IO.Path]::GetTempFileName()
        $arg=@([System.String]::Format("/c @echo on & cd ""{0}"" & ""{1}""  /p:Interactive=False  /t:Undeploy /clp:NoSummary /nologo    /tv:4.0 {2} /p:DeployBizTalkMgmtDB={3} /p:Configuration=Server {4}",  $installDirStartIn,$msbuildExePath , $projectFile, $isFirstBiztalkServer, $addtionalunDeployOptions))
        
      
		#what if check
		if ($pscmdlet.ShouldProcess("$env:computername", "cmd $arg")){
				run-command "cmd" $arg
		}
                     
        Write-Host Application $BiztalkAppName  undeployed 
    

    }
    finally{
         # do nothing
    }
}

function  uninstall-btdfBiztalkApp(){

	[CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [Parameter(Mandatory=$True)]
    [string]$BiztalkAppName

    )

    Write-Host Uninstalling biztalk app $BiztalkAppName .......
    try{
      
		#Get command to uninstall
        $appUninstallCmd = Get-AppUninstallCommand $BiztalkAppName
        
        if ($appUninstallCmd -eq $null){
            write-host No older version of $BiztalkAppName found. Nothing to uninstall
            return
        }
        $appUninstallCmd= [string]  $appUninstallCmd
       
        write-host uninstalling  $appUninstallCmd
		

      
        #use msi exec to remove using msi
        $index=$appUninstallCmd.IndexOf("msiexec.exe", [System.StringComparison]::InvariantCultureIgnoreCase)
        if ($index -gt -1){
            $msiUninstallCmd = $appUninstallCmd.Substring( $index)
           
			#what if check
			if ($pscmdlet.ShouldProcess("$env:computername", "$msiUninstallCmd")){
				 run-command "cmd" "/c $msiUninstallCmd /quiet"
			}
           
        }else{
            Write-Error "Unable to find msiexec.exe uninstall command from the registry..."
        }
      
        
        Write-Host Application $BiztalkAppName  uninstalled 
    

    }
    finally{
         # do nothing
    }
}

function  backup-BiztalkApp(){
	[CmdletBinding(SupportsShouldProcess=$true)]
    param([Parameter(Mandatory=$True)]
    [string]$BiztalkAppName, 
    [Parameter(Mandatory=$True)]
    [string]$backupdir 
    )

    Write-Host Backing up biztalk app $BiztalkAppName to $backupdir .......
    try{
		if (-not( test-biztalkAppExists $BiztalkAppName)){
			write-host $BiztalkAppName doesnt not exist. Nothing to backup
			return
		}

		$templateFileName = [system.string]::Format("{0}_{1}", $BiztalkAppName, $(Get-Date -Format yyyyMMddHHmmss) )
		$packageMsiPath = Join-Path $backupdir ([system.string]::Format("{0}{1}",$templateFileName, ".msi"))
		$packageBindingsPath = Join-Path $backupdir ([system.string]::Format("{0}{1}",$templateFileName, ".xml"))

        #use bts task to export app MSI
        $exportMsiCmd = @([System.String]::Format("/c {0}  exportapp    /ApplicationName:""{1}""  /Package:""{2}""",$BtsTaskPath,$BiztalkAppName,$packageMsiPath))
      
		#whatif 
		if ($pscmdlet.ShouldProcess("$env:computername", "cmd $exportMsiCmd")){
				 run-command "cmd" $exportMsiCmd
		}
       

        #use bts task to export app MSI
        $exportBindingsCmd = @([System.String]::Format("/c {0}  exportBindings    /ApplicationName:""{1}""  /Destination:""{2}""",$BtsTaskPath,$BiztalkAppName,$packageBindingsPath))

		#whatif
		if ($pscmdlet.ShouldProcess("$env:computername", "cmd $exportBindingsCmd")){
				 run-command "cmd" "$exportBindingsCmd"
		}
       
        Write-Host Completed backing up $BiztalkAppName  
    

    }
    finally{
         # do nothing
    }
}

function  Remove-BiztalkApp(){
	[CmdletBinding(SupportsShouldProcess=$true)]
    param([Parameter(Mandatory=$True)]
    [string]$BiztalkAppName
    )

    Write-Host Removing biztalk app $BiztalkAppName .......
    try{
		#if app does not exist, nothing to do..
		if (-not( test-biztalkAppExists $BiztalkAppName)){
			write-host $BiztalkAppName doesnt not exist. Nothing to remove
			return
		}

		
        #use bts task to export app and bindings
        $removeAppCmd = @([System.String]::Format("/c {0}  removeapp    /ApplicationName:""{1}"" ",$BtsTaskPath,$BiztalkAppName))
       

        if ($pscmdlet.ShouldProcess("$env:computername", "$removeAppCmd")){
             run-command "cmd" $removeAppCmd
        }
       
        Write-Host Completed removing $BiztalkAppName  using btstask
    

    }
    finally{
         # do nothing
    }
}

function test-biztalkAppExists(){
	param([Parameter(Mandatory=$True)]
    [string]$BiztalkAppName)


	Write-Host Checking if biztalk app $BiztalkAppName exists.......
    try{
		
        #use bts task to export app and bindings
	    $stdOutLog = [System.IO.Path]::GetTempFileName()
        $ListBiztalkAppCmd = [System.String]::Format("/c {0}  ListApps > ""{1}""",$BtsTaskPath, $stdOutLog)
        
		
		
        run-command "cmd" $ListBiztalkAppCmd

		$biztalkAppslist = gc $stdOutLog | Out-String

        $appNameRegex = "-ApplicationName=""$BiztalkAppName"""

        $appExists= $biztalkAppslist -match $appNameRegex

        return $appExists
    

    }
    finally{
         # do nothing
    }

}

function run-command(){
	
    param(
    [Parameter(Mandatory=$True)]
    [string]$commandToStart, 
    [Parameter(Mandatory=$True)]
    [array]$arguments
    )
        $stdErrLog = [System.IO.Path]::GetTempFileName()
        $stdOutLog = [System.IO.Path]::GetTempFileName()
        write-host Executing command ... $commandToStart  $arguments 
		
		$process  = Start-Process $commandToStart -ArgumentList $arguments  -RedirectStandardOutput $stdOutLog -RedirectStandardError $stdErrLog -wait -PassThru 
		Get-Content $stdOutLog |Write-Host
        
        
		#throw errors if any
		$webdeployerrorsMessage = Get-Content $stdErrLog | Out-String
		if (-not [string]::IsNullOrEmpty($webdeployerrorsMessage)) {throw $webdeployerrorsMessage}

		write-host $commandToStart completed with exit code $process.ExitCode
       
		if ($process.ExitCode -ne 0){
			write-error "Script $commandToStart failed. see log for errors"
		}
}



export-modulemember -function publish-btdfBiztalkApplication