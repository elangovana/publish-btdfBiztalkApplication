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

    publish-btdfBiztalkApplication  -biztalkMsi "C:\mybtdfMsi.msi" -installdir "C:\program files\mybtdfMsi"  -biztalkApplicationName DeploymentFramework.Samples.BasicMasterBindings -BtdfProductName "Deployment Framework for BizTalk - BasicMasterBindings" -backupDir c:\mybackupdir -importIntoBiztalkMgmtDb 1 -deployOptions @{"/p:VDIR_USERNAME"="contoso\adam";"/p:VDIR_USERPASS"="@5t7sd";"/p:ENV_SETTINGS"="""c:\program files\mybtdfMsi\Deployment\PortBindings.xml"""}

    This installs BTDF Biztalk application MSI C:\mybtdfMsi.msi, into install directory C:\program files\mybtdfMsi. in this example, the custom deploy options,  VDIR_USERNAME, VDIR_USERPASS and ENV_SETTINGS are the only deployment options required to deploy the app.

    Note how the value of one of the BTDF deploy options, "/p:ENV_SETTINGS", is double quoted twice """c:\program files\mybtdfMsi\Deployment\PortBindings.xml""". Please make sure values with spaces are double quoted twice in the deploy, undeploy and install options hastable


.EXAMPLE

    publish-btdfBiztalkApplication  -whatif

    To run this script with the awesome whatif switch

.EXAMPLE

    publish-btdfBiztalkApplication  -verbose
    To run this script with increased logging use the -verbose switch

.EXAMPLE
    publish-btdfBiztalkApplication  -msbuildPath "C:\Program Files (x86)\MSBuild\12.0\Bin\msbuild.exe" -btsTaskPath "$env:systemdrive\Program Files (x86)\Microsoft BizTalk Server 2013 R2\BtsTask.exe"
    Customises the paths of msbuild and btstask

#>
function Publish-BTDFBiztalkApplication() {

    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(

        # The path of biztalk MSI created using BTDF
        [Parameter(Mandatory = $True)]
        [string] $biztalkMsi,

        # The directory into which the MSI needs to be installed
        [Parameter(Mandatory = $True)]
        [string]$installdir,

        #The name of the BTDF product name as specified in the btdf project file property <ProductName>..</ProductName>.
        [Parameter(Mandatory = $True)]
        [string] $btdfProductName,

        #The name of the biztalk application. This must match the name of the biztalk application the msi creates.
        [Parameter(Mandatory = $True)]
        [string] $biztalkApplicationName,

        #The backup directory into which an existing Biztalk application, if any, will be backed up to
        [Parameter(Mandatory = $True)]
        $backupDir,

        #This option is useful for deploying in clustered biztalk server environments. Set this to false when installing on all servers except the last one within the clustered environment.
        [Parameter(Mandatory = $False)]
        [boolean] $importIntoBiztalkMgmtDb = $true,

        #This is a hash table of key-value pairs of deploy options that the BTDF deploy UI walks you through. This hash table of custom variables must contain all variables specified in the installwizard.xml of your BTDF project, including the port bindings file.
        #At a bare minimum you will need to specify the port bindings file. Please makes sure that the values with spaces are quoted correctly, for further details see examples
        #Note: There is no need to specify the default variable BT_DEPLOY_MGMT_DB in here, as it is already captured as part of $importIntoBiztalkMgmtDb
        [Parameter(Mandatory = $True)]
        [hashtable]$deployOptions,

        #This is a hash table of key-value pairs of install options. This is the list of public properties available when installing an MSI.
        [hashtable]$installOptions = $NULL,

        #This is a keyvalue pairs of deploy options. This is a list of key value pairs for all custom variables specified in the uninstallwizard.xml of your BTDF project.
        #Note: There is no need to specify the default variable BT_DEPLOY_MGMT_DB in here, as it is already captured as part of $importIntoBiztalkMgmtDb
        [hashtable]$undeployOptions = $NULL,

        #When set to true uninstalls existing version.
        [boolean]$uninstallExistingVersion = $True,

        #This is the BtsTaskPath.
        [string]$btsTaskPath = "$env:systemdrive\Program Files (x86)\Microsoft BizTalk Server 2016\BtsTask.exe",

        #This is the msbuild path.
        [string]$msbuildPath = "$env:systemdrive\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe",

        #This flag when set to true, undeploys all biztalk applications that are dependent on this app to be able to undeploy this app
        [boolean] $undeployDependentApps = $false
    )

    $ErrorActionPreference = "Stop"

    $script:btsTaskPath = $btsTaskPath
    $script:loglevel = get-loglevel

    try {
        Write-verbose "Debug mode in on.. Please note that senstive information such as passwords may be logged in clear text"

        if ($uninstallExistingVersion) {
            unpublish-btdfbiztalkapplication -btdfProductName $btdfProductName -biztalkApplicationName  $biztalkApplicationName -importIntoBiztalkMgmtDb $ImportIntoBiztalkMgmtDb  -msbuildPath $msbuildPath -backupdir $backupDir -undeployDependentApps $undeployDependentApps -btsTaskPath $btsTaskPath
        }

        Write-Host "Step: Installing biztalk msi $BiztalkMsi"
        install-btdfBiztalkApp  $BiztalkMsi -installDir $installdir  -installOptions $installOptions

        Write-Host "Step: Deploying biztalk app $btdfProductName"
        deploy-btdfBiztalkApp -btdfProductName $btdfProductName -importIntoBiztalkMgmtDb $ImportIntoBiztalkMgmtDb -msbuildExePath $msbuildPath -deployOptionsNameValuePairs $deployOptions

        Write-Host "------------------------------------------------------------------"
        Write-Host "Completed installing $btdfProductName using MSI $BiztalkMsi"
    }
    finally {
        #do nothing
    }
}

<#
.SYNOPSIS
    Undeploys biztalk applications created using Biztalk Deployment framework (BTDF)

.DESCRIPTION
    This script undeploys a biztalk MSI built using BTDF, through standard BTDF steps as follows
        - Takes a backup of the existing version of biztalk app, if any, MSI and bindings into a specified backup dir
        - Undeploys the existing version, if any, of biztalk app
        - Uninstalls existing version of biztalk app, if any
        - If there are other biztalk applications dependent on this app, then setting undeployDependentApps to true undeploys them too after taking a backup

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
    unpublish-btdfBiztalkApplication   -biztalkApplicationName DeploymentFramework.Samples.BasicMasterBindings -BtdfProductName "Deployment Framework for BizTalk - BasicMasterBindings"   -backupDir c:\mybackupdir -importIntoBiztalkMgmtDb 1  -undeployDependentApps 1
    This uninstalls the  BTDF Biztalk application product "Deployment Framework for BizTalk - BasicMasterBindings" with biztalk app name  "DeploymentFramework.Samples.BasicMasterBindings".  The undeployDependentApps option also undeploys all dependents apps

.EXAMPLE
    unpublish-btdfBiztalkApplication  -whatif
    To run this script with the awesome whatif switch

.EXAMPLE
    unpublish-btdfBiztalkApplication  -verbose
    To run this script with increased logging use the -verbose switch

.EXAMPLE
    unpublish-btdfBiztalkApplication  -msbuildPath "C:\Program Files (x86)\MSBuild\12.0\Bin\msbuild.exe" -btsTaskPath "$env:systemdrive\Program Files (x86)\Microsoft BizTalk Server 2013 R2\BtsTask.exe"
    Customises the paths of msbuild and btstask

#>

function unpublish-btdfbiztalkapplication() {
    Param (

        #The name of the BTDF product name as specified in the btdf project file property <ProductName>..</ProductName>.
        [Parameter(Mandatory = $True)]
        [string] $btdfProductName,

        #The name of the biztalk application. This must match the name of the biztalk application the msi creates.
        [Parameter(Mandatory = $True)]
        [string] $biztalkApplicationName,

        #The backup directory into which an existing Biztalk application, if any, will be backed up to
        [Parameter(Mandatory = $True)]
        $backupDir,

        #This option is useful for deploying in clustered biztalk server environments. Set this to false when installing on all servers except the last one within the clustered environment.
        [Parameter(Mandatory = $False)]
        [boolean] $importIntoBiztalkMgmtDb = $true,

        #This is a keyvalue pairs of deploy options. This is a list of key value pairs for all custom variables specified in the uninstallwizard.xml of your BTDF project.
        #Note: There is no need to specify the default variable BT_DEPLOY_MGMT_DB in here, as it is already captured as part of $importIntoBiztalkMgmtDb
        [hashtable]$undeployOptions = $NULL,

        #This is the BtsTaskPath.
        [string]$btsTaskPath = "$env:systemdrive\Program Files (x86)\Microsoft BizTalk Server 2016\BtsTask.exe",

        #This is the msbuild path.
        [string]$msbuildPath = "$env:systemdrive\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe",

        #This flag when set to true, undeploys all biztalk applications that are dependent on this app to be able to undeploy this app
        [boolean] $undeployDependentApps = $false
    )
    $ErrorActionPreference = "Stop"

    $script:btsTaskPath = $btsTaskPath
    $script:loglevel = get-loglevel

    Write-Host "Step: Umdeploying existing biztalk app $BiztalkBtdfApp"
    undeploy-btdfBiztalkApp -biztalkAppName $biztalkApplicationName -btdfProductName $btdfProductName -isFirstBiztalkServer $ImportIntoBiztalkMgmtDb -msbuildExePath $msbuildPath -backupdir $backupDir -undeployDependentApps $undeployDependentApps

    Write-Host "Step: Uninstalling existing biztalk app $BiztalkBtdfApp"
    uninstall-btdfBiztalkApp $btdfProductName
}

function get-dependentbiztalkapps() {
    param(
        [Parameter(Mandatory = $True)]
        [string] $biztalkAppName,

        [Parameter(Mandatory = $false)]
        [string] $managmentDbServer = "",

        [Parameter(Mandatory = $false)]
        [string] $managementDb = "",

        #This is the BtsTaskPath.
        [string]$btsTaskPath = "$env:systemdrive\Program Files (x86)\Microsoft BizTalk Server 2016\BtsTask.exe"
    )

    $script:btsTaskPath = $btsTaskPath

    #if no sql server details are passed in attempt  to get this through btstask
    if ([string]::IsNullOrEmpty($managmentDbServer) -or [string]::IsNullOrEmpty($managementDb)) {
        $managmentDbServer = get-biztalkManagementServer
        $managmentDbServer = $managmentDbServer[0]
        $managementDb = $managmentDbServer[1]
    }

    [System.Collections.ArrayList]$result = [array]$(get-dependentbiztalkappsrecurse $biztalkAppName $managmentDbServer $managementDb)

    #The result also contains the biztalk app name who dependents we are looking for..
    if ($result.Contains($biztalkAppName) -and $result[$($result.Count - 1)] -eq $biztalkAppName) {
        $null = $result.Remove($biztalkAppName)
    }

    return [array]$result
}

function get-loglevel() {
    if ($PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent) {return 2}
    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {return 3}

    return 1
}

function get-msbuildloglevel() {
    Param(
        [Parameter(Mandatory = $True)]
        [int]$loglevel
    )

    if ($loglevel -ge 3) {return "diag"}
    if ($loglevel -ge 2) {return "detailed"}

    return "normal"
}

function get-msiexecloglevel() {
    Param(
        [Parameter(Mandatory = $True)]
        [int]$loglevel
    )

    if ($loglevel -ge 3) {return "x"}
    if ($loglevel -ge 2) {return "v"}

    return "*"
}

function flatten-keyValues() {
    Param(
        [hashtable]$hashMap = $null
    )

    $flattendMap = ""
    if ($null -eq $hashMap) {
        return $flattendMap
    }

    foreach ($h in $hashMap.GetEnumerator()) {
        $flattendMap = $flattendMap + " " + $($h.Name) + "=" + $($h.Value)
    }

    return $flattendMap
}

function Get-AppUninstallCommand() {
    param(
        [Parameter(Mandatory = $True)]
        [string]$appDisplayName
    )

    $app = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\**" | Where-Object {
        $_.DisplayName -like "$appDisplayName*"
    }

    if ($null -eq $app) {
        $app = Get-ItemProperty "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\**" | Where-Object {
            $_.DisplayName -like "$appDisplayName*"
        }
    }

    #Found a match in the registry
    if ($null -ne $app) {
        #more than one match for the app uninstall command.. Error case.. this script doesnt support this type of uninstall
        if ($app.Count -gt 1) {
            Write-Error "Multiple items matched when looking for uninstall command using app name HKLM:\Software\....\Microsoft\Windows\CurrentVersion\Uninstall\$appDisplayName*." $($app | Format-Table -Property DisplayName, PSPath -Wrap | Out-String) "This script does not currently support use cases where mutiple products with the same name prefix are found."
        }
        return $app.uninstallstring
    }

    return $null
}

function get-btdfUndeployShortCut() {
    param([Parameter(Mandatory = $True)]
        [string]$btdfBiztalkAppName
    )
    #get BTDF shortcuts in the startmenu for the app, regardless of version
    $undeployAppBasePath = "$Env:SystemDrive\ProgramData\Microsoft\Windows\Start Menu\Programs\$btdfBiztalkAppName*\undeploy *.lnk"
    $undeployShortcut = get-btdfShortCut $undeployAppBasePath

    return $undeployShortcut
}

function get-btdfDeployShortCut() {
    param([Parameter(Mandatory = $True)]
        [string]$btdfBiztalkAppName
    )
    #get BTDF shortcuts in the startmenu for the app, regardless of version
    $deployAppBasePath = "$Env:SystemDrive\ProgramData\Microsoft\Windows\Start Menu\Programs\$btdfBiztalkAppName*\deploy *.lnk"
    $deployShortcut = get-btdfShortCut $deployAppBasePath

    return $deployShortcut
}

function get-btdfShortCut() {
    param([Parameter(Mandatory = $True)]
        [string]$shortcutSearchPath
    )

    #ensure there is exactly one match for the path, else appropriate error or warning
    $items = Get-Item $shortcutSearchPath

    if ($items.Count -gt 1) {
        Write-Error "Multiple items matching $shortcutSearchPath found , $items. Unable to detemine which app needs to be managed!!"
    }
    elseif ($items.Count -eq 0) {
        Write-Warning "No items found using search path $shortcutSearchPath"
    }

    $undeployShortcut = $items[0]
    #Final check to makesure it is a file and not directory!!
    if (-not (Test-Path $undeployShortcut -PathType Leaf)) {
        Write-Error "Expected shortcut to be a file, found a folder instead!!"
    }

    return $undeployShortcut
}

function get-btdfProjectFileName() {
    param(
        [Parameter(Mandatory = $True)]
        [string]$btdfDeployOrUndeployShortcutFileName
    )

    if (-not (Test-Path $btdfDeployOrUndeployShortcutFileName -PathType Leaf)) {
        Write-Error "The file $btdfDeployOrUndeployShortcutFileName not found"
    }

    $shortcutObj = get-shortcutProperties $btdfDeployOrUndeployShortcutFileName
    $projectFileRegex = "\s[^:]*\.btdfproj"

    if ($shortcutObj.TargetArguments -match $projectFileRegex) {
        $projectFile = ([string]$matches[0]).Trim()
    }
    else {
        Write-Error "Could not find any project file matching regex $projectFileRegex in expression $shortcutObj.TargetArguments"
    }

    return $projectFile
}

function get-shortcutProperties() {
    param(
        [Parameter(Mandatory = $True)]
        [string]$shortCut
    )
    $shell = $null

    try {
        $shell = New-Object -ComObject WScript.Shell
        $properties = @{
            ShortcutName = $shortCut.Name
            Target = $shell.CreateShortcut($shortCut).targetpath
            StartIn = $shell.CreateShortcut($shortCut).WorkingDirectory
            TargetArguments = $shell.CreateShortcut($shortCut).Arguments
        }
        return New-Object PSObject -Property $Properties
    }
    finally {
        if ($null -eq $shell) {
            [Runtime.InteropServices.Marshal]::ReleaseComObject($Shell) | Out-Null
        }
    }
}

<#
.SYNOPSIS
    Installs the new version of biztalk MSI created using BTDF

.DESCRIPTION
    This script is used as a step during the deploy script, but can be called individually to be able to run SettingsFileGenerator and replace 
    settings for the current environment using Octopus variables. After using this step directly, you should call deploy-btdfBiztalkApp to continue the BTDF process.

    This script was tested with Biztalk 2016 and BTDF Release 5.7

.INPUTS
    None

.OUTPUTS
    None


 .LINK
    https://github.com/eloekset/publish-btdfBiztalkApplication forked from https://github.com/elangovana/publish-btdfBiztalkApplication

.EXAMPLE

    install-btdfBiztalkApp -biztalkMsi "C:\mybtdfMsi.msi" -installdir "C:\program files\mybtdfMsi" -installOptions @{<msiexec parameters>}

    This installs BTDF Biztalk application MSI C:\mybtdfMsi.msi, into install directory C:\program files\mybtdfMsi.

.EXAMPLE

    install-btdfBiztalkApp -whatif

    To run this script with the awesome whatif switch

.EXAMPLE

    install-btdfBiztalkApp -verbose
    To run this script with increased logging use the -verbose switch

#>
function install-btdfBiztalkApp() {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        # The path of biztalk MSI created using BTDF
        [Parameter(Mandatory = $True)]
        [string]$BiztalkAppMSI,

        # The directory into which the MSI needs to be installed
        [Parameter(Mandatory = $True)]
        [string]$installDir,

        #This is a hash table of key-value pairs of install options. This is the list of public properties available when installing an MSI.
        [hashtable]$installOptions = $null
    )
    $script:loglevel = get-loglevel
    $stdOutLog = Join-Path $([System.IO.Path]::GetTempPath())  $([System.Guid]::NewGuid().ToString())
    $additionalInstallProperties = flatten-keyValues $installOptions

    try {
        $msiloglevel = get-msiexecloglevel $script:loglevel
        $args = @("/c msiexec /i ""$BiztalkAppMSI"" /q /l$msiloglevel  $stdOutLog INSTALLDIR=""$installDir"" $additionalInstallProperties")

        #what if check
        if ($pscmdlet.ShouldProcess("$env:computername", "cmd $args")) {
            Start-Command "cmd" $args
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $msiOutput = Get-Content $stdOutLog | Out-String
        Write-Error "$ErrorMessage $msiOutput"
    }

    $msiOutput = Get-Content $stdOutLog | Out-String
    write-host $msiOutput
}

<#
.SYNOPSIS
    Deploys an already installed BizTalk application created using BTDF

.DESCRIPTION
    This script is used as a step during the deploy script, but can be called individually to be able to run SettingsFileGenerator and replace 
    settings for the current environment using Octopus variables. Before using this step directly, you must call install-btdfBiztalkApp to install the MSI.

    This script was tested with Biztalk 2016 and BTDF Release 5.7

.INPUTS
    None

.OUTPUTS
    None


 .LINK
    https://github.com/eloekset/publish-btdfBiztalkApplication forked from https://github.com/elangovana/publish-btdfBiztalkApplication

.EXAMPLE

    deploy-btdfBiztalkApp -BtdfProductName "Deployment Framework for BizTalk - BasicMasterBindings" -importIntoBiztalkMgmtDb 1 -deployOptions @{"/p:VDIR_USERNAME"="contoso\adam";"/p:VDIR_USERPASS"="@5t7sd";"/p:ENV_SETTINGS"="""c:\program files\mybtdfMsi\Deployment\PortBindings.xml"""}

    This installs BTDF Biztalk application MSI C:\mybtdfMsi.msi, into install directory C:\program files\mybtdfMsi. in this example, the custom deploy options,  VDIR_USERNAME, VDIR_USERPASS and ENV_SETTINGS are the only deployment options required to deploy the app.

    Note how the value of one of the BTDF deploy options, "/p:ENV_SETTINGS", is double quoted twice """c:\program files\mybtdfMsi\Deployment\PortBindings.xml""". Please make sure values with spaces are double quoted twice in the deploy, undeploy and install options hastable

.EXAMPLE

    deploy-btdfBiztalkApp -whatif

    To run this script with the awesome whatif switch

.EXAMPLE

    deploy-btdfBiztalkApp -verbose
    To run this script with increased logging use the -verbose switch

#>
function deploy-btdfBiztalkApp() {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        # The name of the BTDF product name as specified in the btdf project file property <ProductName>..</ProductName>.
        [Parameter(Mandatory = $True)]
        [string]$btdfProductName,

        # This option is useful for deploying in clustered biztalk server environments. Set this to false when installing on all servers except the last one within the clustered environment.
        [Parameter(Mandatory = $True)]
        [boolean]$importIntoBiztalkMgmtDb,

        # This is the msbuild path.
        [Parameter(Mandatory = $False)]
        [string]$msbuildExePath = "$env:systemdrive\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe",

        # This is a hash table of key-value pairs of deploy options that the BTDF deploy UI walks you through. This hash table of custom variables must contain all variables specified in the installwizard.xml of your BTDF project, including the port bindings file.
        # At a bare minimum you will need to specify the port bindings file. Please make sure that the values with spaces are quoted correctly, for further details see examples.
        # Note: There is no need to specify the default variable BT_DEPLOY_MGMT_DB in here, as it is already captured as part of $isLastBiztalkServer.
        [hashtable]$deployOptionsNameValuePairs = $null
    )
    Write-Host "********Deploying biztalk app $btdfProductName ......."

    try {
        $appUninstallCmd = Get-AppUninstallCommand $btdfProductName

        #extra check for whatif, when running without any version of the biztalk app installed
        if (-not($pscmdlet.ShouldProcess("$env:computername", "deploy-btdfBiztalkApp"))) {
            return
        }

        if ($null -eq $appUninstallCmd) {
            Write-Error "No version of $btdfProductName found. Please ensure this app is installed first"
        }

        $deployShortCut = get-btdfdeployShortcut $btdfProductName
        Write-Host "Found shortcut for deploying app $deployShortCut"
        $projectFile = get-btdfProjectFileName  $deployShortCut
        $installStartInDir = $(get-shortcutProperties $deployShortCut).StartIn

        $addtionalDeployOptions = Flatten-KeyValues $deployOptionsNameValuePairs

        $stdErrorLog = [System.IO.Path]::GetTempFileName()
        $msbuildloglevel = get-msbuildloglevel $script:loglevel
        $arg = @([System.String]::Format("/c @echo on & cd /d ""{0}"" & ""{1}"" /p:Interactive=False  /t:Deploy /clp:NoSummary /nologo   /tv:4.0 {2} /v:{5} /p:DeployBizTalkMgmtDB={3} /p:Configuration=Server {4}", $installStartInDir, $msbuildExePath, $projectFile, $importIntoBiztalkMgmtDb, $addtionalDeployOptions, $msbuildloglevel))

        Start-Command "cmd" $arg
        Write-Host "Application $btdfBiztalkAppName deployed"
    }
    finally {
        # do nothing
    }
}
function undeploy-DependentBiztalkApps() {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $True)]
        [string]$biztalkAppName,

        [Parameter(Mandatory = $True)]
        [boolean]$isFirstBiztalkServer,

        [Parameter(Mandatory = $True)]
        [string]$backupdir
    )
    Write-Host "............Undeploying dependent apps for $biztalkAppName ......."

    try {
        if (-not $isFirstBiztalkServer) {
            Write-Host "Not first biztalk server, no dependent apps to check. Exiting..."
            return
        }

        #check if biztalk app exists, els do nothing and return
        if (-not(test-biztalkAppExists $biztalkAppName)) {
            Write-Host "The application $biztalkAppName does not exist on the biztalk sever. Nothing to undeploy"
            return
        }

        $mgmtServerDb = get-biztalkManagementServer
        [array]$dependentAppsToUndeploy = [array]$(get-dependentbiztalkapps $biztalkAppName $mgmtServerDb[0] $mgmtServerDb[1])

        if ($null -eq $dependentAppsToUndeploy -or $dependentAppsToUndeploy.Count -eq 0) {
            Write-Host "No dependant apps to undeploy.. exiting"
            return
        }

        if (Test-MessagBoxInstances  $dependentAppsToUndeploy $mgmtServerDb[0] $mgmtServerDb[1]) {
            Write-Error "There are active instances associated with one or more applications in $dependentAppsToUndeploy.."
        }

        Write-Host "Found dependent apps that must be undeployed.. $dependentAppsToUndeploy"
        Write-Host $($dependentAppsToUndeploy | Out-String)

        foreach ($app in $dependentAppsToUndeploy) {
            Write-Verbose "stopping dependent app $appToUndeploy"
            stop-biztalkapplication $app $isFirstBiztalkServer $mgmtServerDb[0] $mgmtServerDb[1]
        }

        #just do one more check before backing up and removing apps
        if (Test-MessagBoxInstances  $dependentAppsToUndeploy $mgmtServerDb[0] $mgmtServerDb[1]) {
            Write-Error "One or more dependent applications cannot be undeployed. There are active instances associated with one or more applications in $dependentAppsToUndeploy.."
        }

        # Make sure all backs up are done before removing apps
        foreach ($appToUndeploy in $dependentAppsToUndeploy) {
            #Take a backup of biztalk app before undeploying...
            Write-Verbose "Backing up $appToUndeploy to $backupdir"
            backup-BiztalkApp $appToUndeploy $backupdir
        }

        #remove apps
        foreach ($appToUndeploy in $dependentAppsToUndeploy) {
            #Take a backup of biztalk app before undeploying...
            Write-Verbose "Removing dependent app $appToUndeploy"
            Remove-BiztalkApp $appToUndeploy
        }
    }
    finally {
        # do nothing
    }
}

function undeploy-btdfBiztalkApp() {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $True)]
        [string]$biztalkAppName,

        [Parameter(Mandatory = $True)]
        [string]$btdfProductName,

        [Parameter(Mandatory = $True)]
        [boolean]$isFirstBiztalkServer,

        [Parameter(Mandatory = $True)]
        [string]$backupdir,

        [Parameter(Mandatory = $True)]
        [string]$msbuildExePath,

        [hashtable]$undeployOptionsNameValuePairs = $null,

        [boolean]$undeployDependentApps = $false
    )
    Write-Host "********Undeploying  $btdfProductName ......."

    try {
        #check if biztalk app exists, els do nothing and return
        if (-not(test-biztalkAppExists $biztalkAppName)) {
            Write-Host "The application $biztalkAppName does not exist on the biztalk sever. Nothing to undeploy"
            return
        }

        $mgmtServerDb = get-biztalkManagementServer

        #getDependant applications
        [array]$dependantApps = [array]$(get-dependentbiztalkapps $biztalkAppName $mgmtServerDb[0] $mgmtServerDb[1])
        $tmpAppsToCheckActiveInstances = $dependantApps + @($biztalkAppName)

        if (Test-MessagBoxInstances $tmpAppsToCheckActiveInstances $mgmtServerDb[0] $mgmtServerDb[1]) {
            Write-Error "One or more dependent applications cannot be undeployed. There are active instances associated with one or more applications in $dependentAppsToUndeploy.."
        }

        # all seems ok,, stop application..
        stop-biztalkapplication $biztalkAppName $isFirstBiztalkServer $mgmtServerDb[0] $mgmtServerDb[1]

        #if forced undeploy, then undeploy dependents apps
        if ($undeployDependentApps) {
            undeploy-DependentBiztalkApps $biztalkAppName $isFirstBiztalkServer $backupdir
        }
        elseif ($null -ne $dependantApps) {
            Write-Verbose "Dependent apps $dependantApps"

            if (($dependantApps -is [array] -and $dependantApps.Count -gt 0) -or ($dependantApps -is [Int32] -and $dependantApps -gt 0)) {
                Write-Error "The biztalk application $biztalkAppName cannot be undeployed as there are other applications that depend on it. To undeploy dependent applications, set the undeployDependentApps option to true. Or manually remove the apps $dependantApps"
            }
        }

        #Take a backup of biztalk app before undeploying...
        backup-BiztalkApp $biztalkAppName $backupdir

        #Check if biztalk app can be undeployed using BTDF undeploy. If BTDF undeploy not found, undeploy using BTSTask.exe
        $appUninstallCmd = Get-AppUninstallCommand $btdfProductName
        if ($null -eq $appUninstallCmd) {
            Write-Host "No older version of $btdfProductName found. Nothing to undeploy"

            #BTDF undeploy not found, undeploy using BTSTask.exe
            if (test-biztalkAppExists $biztalkAppName) {
                #remove app only if firstbiztalk server
                if ($isFirstBiztalkServer) {
                    Write-Warning "No Btdf command to undeploy this product $btdfProductName exists, but the biztalk application $biztalkAppName exists..  Using Btstask instead to remove app $biztalkAppName..."
                    Remove-BiztalkApp $biztalkAppName
                }
            }
            return
        }

        #undeploy using btdf undeploy
        $undeployShortCut = get-btdfUndeployShortcut $btdfProductName
        Write-Host Found shortcut for undeploying app $undeployShortCut
        $installDirStartIn = $(get-shortcutProperties $undeployShortCut).StartIn
        $projectFile = get-btdfProjectFileName  $undeployShortCut

        $addtionalunDeployOptions = flatten-keyValues $undeployOptionsNameValuePairs
        $msbuildloglevel = get-msbuildloglevel $script:loglevel
        $stdErrorLog = Join-Path $([System.IO.Path]::GetTempPath()) $([System.Guid]::NewGuid().ToString())
        $arg = @([System.String]::Format("/c @echo on & cd /d ""{0}"" & ""{1}""  /p:Interactive=False  /p:ContinueOnError=FALSE /t:Undeploy /clp:NoSummary /nologo  /verbosity:{5}  /tv:4.0 {2} /p:DeployBizTalkMgmtDB={3} /p:Configuration=Server {4}", $installDirStartIn, $msbuildExePath, $projectFile, $isFirstBiztalkServer, $addtionalunDeployOptions, $msbuildloglevel))

        #what if check
        if ($pscmdlet.ShouldProcess("$env:computername", "cmd $arg")) {
            Start-Command "cmd" $arg
        }

        Write-Host "Application $biztalkAppName undeployed"
    }
    finally {
        # do nothing
    }
}

function stop-biztalkapplication() {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $True)]
        [string]$biztalkAppName,

        [Parameter(Mandatory = $True)]
        [boolean]$IsFirstBiztalkServer,

        [Parameter(Mandatory = $True)]
        [string]$managmentDbServer,

        [string]$managementdb = "BizTalkMgmtDb"
    )
    #=== Make sure the ExplorerOM assembly is loaded ===#

    #Do nothing if  not the first biztalk server
    if (-not $IsFirstBiztalkServer) {
        return
    }

    [void][System.reflection.Assembly]::LoadWithPartialName("Microsoft.BizTalk.ExplorerOM")
    $Catalog = New-Object Microsoft.BizTalk.ExplorerOM.BtsCatalogExplorer
    $Catalog.ConnectionString = "SERVER=$managmentDbServer;DATABASE=$managementdb;Integrated Security=SSPI"

    #=== Connect the BizTalk Management database ===#
    foreach ($app in $Catalog.Applications) {
        if ($($app.Name) -ieq $biztalkAppName) {
            Write-Host Issuing stop command to $biztalkAppName..
            #What if support
            if ($pscmdlet.ShouldProcess("$managmentDbServer\\$managementdb\\$biztalkAppName", "StopAll")) {
                $app.Stop([Microsoft.BizTalk.ExplorerOM.ApplicationStopOption] "StopAll")
                $Catalog.SaveChanges()
            }
        } #end of application match check
    }
}

function uninstall-btdfBiztalkApp() {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $True)]
        [string]$btdfProductName
    )
    Write-Host "******** Uninstalling biztalk app $btdfProductName ......."

    try {
        #Get command to uninstall
        $appUninstallCmd = Get-AppUninstallCommand $btdfProductName

        if ($null -eq $appUninstallCmd) {
            Write-Host "No older version of $btdfProductName found. Nothing to uninstall"
            return
        }

        $appUninstallCmd = [string]$appUninstallCmd
        Write-Host uninstalling $appUninstallCmd

        #use msi exec to remove using msi
        $index = $appUninstallCmd.IndexOf("msiexec.exe", [System.StringComparison]::InvariantCultureIgnoreCase)

        if ($index -gt -1) {
            $msiUninstallCmd = $appUninstallCmd.Substring( $index)

            #what if check
            if ($pscmdlet.ShouldProcess("$env:computername", "$msiUninstallCmd")) {
                Start-Command "cmd" "/c $msiUninstallCmd /quiet"
            }
        }
        else {
            Write-Error "Unable to find msiexec.exe uninstall command from the registry..."
        }

        Write-Host "Application $btdfProductName uninstalled"
    }
    finally {
        # do nothing
    }
}

function Test-MessagBoxInstances() {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $True)]
        [array]$biztalkApplications,

        [Parameter(Mandatory = $True)]
        [string]$biztalkMgmtBoxServer,

        [string]$biztalkMgmtBoxDb = "BizTalkMgmtDb"
    )
    Add-Type -AssemblyName ('Microsoft.BizTalk.Operations, Version=3.0.1.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL')
    $bo = New-Object Microsoft.BizTalk.Operations.BizTalkOperations $biztalkMgmtBoxServer, $biztalkMgmtBoxDb
    $tmpServiceInstances = $bo.GetServiceInstances()
    [System.Collections.ArrayList]$serviceInstances = @()
    foreach ($instance in $tmpServiceInstances) {
        $serviceInstances.Add($instance)
    }

    [array]$activeInstances = $serviceInstances | Where-Object {$biztalkApplications.Contains($_.Application) -and $_.Messages.Count -gt 0} | Group-Object Application, InstanceStatus, ServiceType | Select-Object Name, Count
    Write-Host "Active applications $($activeInstances.Length), service instances: " ($activeInstances | Format-Table -auto | Out-String)

    return $($activeInstances.Count -gt 0)
}
function backup-BiztalkApp() {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $True)]
        [string]$BiztalkAppName,

        [Parameter(Mandatory = $True)]
        [string]$backupdir
    )
    Write-Host "..........Backing up biztalk app $BiztalkAppName to $backupdir ......."
    try {
        if (-not( test-biztalkAppExists $BiztalkAppName)) {
            Write-Host "$BiztalkAppName doesnt not exist. Nothing to backup"
            return
        }

        $templateFileName = [system.string]::Format("{0}_{1}", $BiztalkAppName, $(Get-Date -Format yyyyMMddHHmmss))
        $packageMsiPath = Join-Path $backupdir ([system.string]::Format("{0}{1}", $templateFileName, ".msi"))
        $packageBindingsPath = Join-Path $backupdir ([system.string]::Format("{0}{1}", $templateFileName, ".xml"))

        #use bts task to export app MSI
        $exportMsiCmd = @([System.String]::Format("/c echo Exporting biztalk MSI using btsTask.. & ""{0}""  exportapp    /ApplicationName:""{1}""  /Package:""{2}""", $BtsTaskPath, $BiztalkAppName, $packageMsiPath))

        #whatif
        if ($pscmdlet.ShouldProcess("$env:computername", "cmd $exportMsiCmd")) {
            Start-Command "cmd" $exportMsiCmd
        }

        #use bts task to export app bindings
        $exportBindingsCmd = @([System.String]::Format("/c echo Exporting biztalk bindings using btsTask..& ""{0}""  exportBindings    /ApplicationName:""{1}""  /Destination:""{2}""", $BtsTaskPath, $BiztalkAppName, $packageBindingsPath))

        #whatif
        if ($pscmdlet.ShouldProcess("$env:computername", "cmd $exportBindingsCmd")) {
            Start-Command "cmd" "$exportBindingsCmd"
        }

        Write-Host "Completed backing up $BiztalkAppName"
    }
    finally {
        # do nothing
    }
}
function Remove-BiztalkApp() {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $True)]
        [string]$BiztalkAppName
    )
    Write-Host ".........Removing biztalk app $BiztalkAppName ......."

    try {
        #if app does not exist, nothing to do..
        if (-not(test-biztalkAppExists $BiztalkAppName)) {
            Write-Host "$BiztalkAppName doesnt not exist. Nothing to remove"
            return
        }

        #use bts task to remove app
        $removeAppCmd = @([System.String]::Format("/c echo Removing biztalk app using btstask... & ""{0}""  removeapp    /ApplicationName:""{1}"" ", $BtsTaskPath, $BiztalkAppName))

        if ($pscmdlet.ShouldProcess("$env:computername", "$removeAppCmd")) {
            Start-Command "cmd" $removeAppCmd
        }

        Write-Host "Completed removing $BiztalkAppName using btstask"
    }
    finally {
        # do nothing
    }
}
function get-biztalkManagementServer() {
    param(
        [string]$BiztalkTaskPath = $btsTaskPath
    )
    Write-Host "Get Biztallk Management server"
    $exportedSettingsFile = Join-Path $([System.IO.Path]::GetTempPath())  $([System.Guid]::NewGuid().ToString() + ".xml")
    $exportBiztalkSettingsCmd = [System.String]::Format("/c echo Getting biztalk settings using BTSTask & ""{0}""  exportsettings -Destination:""{1}""", $BiztalkTaskPath, $exportedSettingsFile)

    Start-Command "cmd" $exportBiztalkSettingsCmd

    [xml]$XmlDocument = Get-Content -Path $exportedSettingsFile
    [string]$server = $XmlDocument.Settings.ExportedGroup

    Write-Host "Exported group $server"

    return $server.Split(":")
}
function test-biztalkAppExists() {
    param(
        [Parameter(Mandatory = $True)]
        [string]$BiztalkAppName
    )
    Write-Host "Checking if biztalk app $BiztalkAppName exists......."

    try {
        #use bts task to list apps
        $stdOutLog = Join-Path $([System.IO.Path]::GetTempPath())  $([System.Guid]::NewGuid().ToString())
        $ListBiztalkAppCmd = [System.String]::Format("/c echo  & ""{0}""  ListApps > ""{1}""", $BtsTaskPath, $stdOutLog)

        Start-Command "cmd" $ListBiztalkAppCmd
        $biztalkAppslist = Get-Content $stdOutLog | Out-String
        $appNameRegex = "-ApplicationName=""$BiztalkAppName"""
        $appExists = $biztalkAppslist -match $appNameRegex

        return $appExists
    }
    finally {
        # do nothing
    }
}

<#
.SYNOPSIS
    Runs Start-Process with a bit of logging and error handling

.DESCRIPTION
    This script is called several places internally, but is exported for ruse directly from Octopus.

.INPUTS
    None

.OUTPUTS
    None

 .LINK
    https://github.com/eloekset/publish-btdfBiztalkApplication forked from https://github.com/elangovana/publish-btdfBiztalkApplication

.EXAMPLE

    Start-Command -commandToStart "msiexec.exe" -arguments "/i C:\mybtdfMsi.msi"

    This installs BTDF Biztalk application MSI C:\mybtdfMsi.msi.

.EXAMPLE

    Start-Command -verbose
    To run this script with increased logging use the -verbose switch

#>
function Start-Command() {
    param(
        # Command to start
        [Parameter(Mandatory = $True)]
        [string]$commandToStart,

        # Arguments to be passed to the command
        [Parameter(Mandatory = $True)]
        [array]$arguments,

        # Set WorkingDirectory to save characters for relative paths
        [Parameter(Mandatory = $False)]
        [string]$workingDirectory = $null
    )
    $stdErrLog = Join-Path $([System.IO.Path]::GetTempPath()) $([System.Guid]::NewGuid().ToString())
    $stdOutLog = Join-Path $([System.IO.Path]::GetTempPath()) $([System.Guid]::NewGuid().ToString())
    Write-Host "Executing command ... $commandToStart"
    Write-Verbose "Executing command ... $commandToStart"

    if ([System.String]::IsNullOrEmpty($workingDirectory)) {
        $process = Start-Process $commandToStart -ArgumentList $arguments -RedirectStandardOutput $stdOutLog -RedirectStandardError $stdErrLog -wait -PassThru        
    } else {
        $process = Start-Process $commandToStart -ArgumentList $arguments -WorkingDirectory $workingDirectory -RedirectStandardOutput $stdOutLog -RedirectStandardError $stdErrLog -wait -PassThru
    }
    
    Get-Content $stdOutLog | Write-Host

    #throw errors if any
    $webdeployerrorsMessage = Get-Content $stdErrLog | Out-String
    if (-not [string]::IsNullOrEmpty($webdeployerrorsMessage)) {
        throw $webdeployerrorsMessage
    }

    Write-Host "$commandToStart completed with exit code $($process.ExitCode)"
    if ($process.ExitCode -ne 0) {
        Write-Error "Script $commandToStart failed. see log for errors"
    }
}

<#
.SYNOPSIS
    Runs EnvironmentSettingsExporter.exe and returns the path to the folder of the exported files.

.DESCRIPTION
    This script should be called before using Octopus Substitute Variables in Files community step: https://octopus.com/docs/deployment-process/configuration-features/substitute-variables-in-files

.INPUTS
    None

.OUTPUTS
    Path to folder where exported environment settings files are stored.


 .LINK
    https://github.com/eloekset/publish-btdfBiztalkApplication forked from https://github.com/elangovana/publish-btdfBiztalkApplication

.EXAMPLE

    Export-EnvironmentSettings -installDir "C:\Octopus\Applications\..."

    This exports environment settings to a relative path default for BTDF.

.EXAMPLE

    Export-EnvironmentSettings -installDir "C:\Octopus\Applications\..." -verbose
    To run this script with increased logging use the -verbose switch

#>
function Export-EnvironmentSettings() {
    param(
        # Command to start
        [Parameter(Mandatory = $True)]
        [string]$installDir
    )
    #Run EnvironmentSetttingsExporter.exe to genereate xml file for environment 
    #to replace its values with matching Octopus variables
    Write-Host "Export environment settings using BTDF"
    Write-Verbose "installDir = $installDir"

    ##Tools expected to be found at Deployment\Framework\DeployTools
    $envSettingsExporterPath = "Deployment\Framework\DeployTools\EnvironmentSettingsExporter.exe"
    $envSettingsExporterPath = Join-Path $installDir $envSettingsExporterPath
    Write-Verbose "envSettingsExporterPath = $envSettingsExporterPath"

    ##Export settings to Deployment\EnvironmentSettings
    $envSettingsDirPath = "Deployment\EnvironmentSettings"
    Write-Verbose "envSettingsDirPath = $envSettingsDirPath"
    $settingsFileGeneratorPath = Join-Path $envSettingsDirPath "SettingsFileGenerator.xml"
    Write-Verbose "settingsFileGeneratorPath = $settingsFileGeneratorPath"
    $arg = @("""$settingsFileGeneratorPath"" ""$envSettingsDirPath"" ")

    #TODO: Include this what if check when exporting this into the PowerShell module:
    #what if check
    #if ($pscmdlet.ShouldProcess("$env:computername", "cmd $arg")) {
    Start-Command $envSettingsExporterPath $arg -WorkingDirectory $installDir
    #}

    $returnPath = Join-Path $installDir $envSettingsDirPath
    Write-Verbose "returnPath = $returnPath"
    return $returnPath
}

<#
.SYNOPSIS
    Looks up existing properties in a settings file and replaces values with those provided by Octopus.

.DESCRIPTION
    This script can be used instead of the Octopus Substitute Variables in Files community step: https://octopus.com/docs/deployment-process/configuration-features/substitute-variables-in-files
    Using this script has the advantages described here: https://github.com/eloekset/publish-btdfBiztalkApplication/issues/8

.INPUTS
    None

.OUTPUTS
    None

 .LINK
    https://github.com/eloekset/publish-btdfBiztalkApplication forked from https://github.com/elangovana/publish-btdfBiztalkApplication

.EXAMPLE

    Substitute-XmlSettingsFileValues -settingsFilePath "C:\Octopus\Applications\..." -substituteSettings @{ Setting1 = "Value 1" Setting2 = "Value 2" }

    Replaces values of the file with the ones passed as substituteSettings.

.EXAMPLE

    Substitute-XmlSettingsFileValues -settingsFilePath "C:\Octopus\Applications\..." -substituteSettings @{ Setting1 = "Value 1" Setting2 = "Value 2" } -verbose
    To run this script with increased logging use the -verbose switch. Will log properties not found and also properties not overriden.

#>
function Substitute-XmlSettingsFileValues() {
    param(
        # Path to xml file
        [Parameter(Mandatory = $True)]
        [string]$settingsFilePath,
        # Settings to replace existing ones
        [Parameter(Mandatory = $True)]
        [hashtable]$substituteSettings
    )
    # Load source XML
    $xml = New-Object -TypeName XML
    $xml.Load($settingsFilePath)

    ## Replace values of XML elements matching key name
    Foreach($key in $substituteSettings.Keys) {
        $xmlProperty = Select-XML -Xml $xml -XPath "/settings/property[@name='$key']"

        if ($null -ne $xmlProperty) {
            $newValue = $substituteSettings[$key]
            $existingValue = $xmlProperty.Node.InnerText
            $xmlProperty.Node.InnerText = $newValue
            Write-Output "Property ""$key"" got new value ""$newValue"" for existing value ""$existingValue"""
        } else {
            Write-Verbose "Found no existing property named ""$key"""
        }
    }

    ## Log existing settings in XML that got no override in Octopus
    Foreach($xmlProperty in (Select-XML -Xml $xml -XPath "/settings/property")) {
        $xmlPropertyName = $xmlProperty.Node.Attributes.GetNamedItem("name").Value
        if(-not $substituteSettings.ContainsKey($xmlPropertyName)) {
            Write-Verbose "No substitute setting provided for property $xmlPropertyName"
        }
    }
 
    $Xml.Save($settingsFilePath)
}

function get-dependentbiztalkappslevelone() {
    param(
        [Parameter(Mandatory = $True)]
        [string]$biztalkAppName,

        [Parameter(Mandatory = $True)]
        [string]$managmentDbServer,

        [string] $managementdb = "BizTalkMgmtDb"
    )
    $cmd = " select appd.nvcName apps from bts_application app " +
    " join bts_assembly ass on app.nID =  ass.nApplicationID  " +
    " join [bts_libreference] lr on lr.idlib = ass.nID " +
    " join bts_assembly assd on assd.nID = lr.idapp " +
    " join bts_application appd on assd.nApplicationID = appd.nID " +
    " where app.nvcName = '$biztalkAppName'  and app.nvcName != appd.nvcName" +
    " union  " +
    " select app.nvcName from bts_application app " +
    " join bts_application_reference appr on appr.nApplicationID = app.nID " +
    " join bts_application appd on appd.nID = appr.nReferencedApplicationID " +
    "  where appd.nvcName = '$biztalkAppName' "

    Write-Verbose $cmd
    Write-Host "DB server: " $managmentDbServer " DB name: " $managementdb

    if (!(Get-module "SqlServer")) {
        Import-Module "SqlServer" -DisableNameChecking
    }
    $appsdatarow = Invoke-Sqlcmd -ServerInstance $managmentDbServer -Query $cmd -Database $managementdb

    return [array]$appsdatarow.apps
}

function get-itemsnotinlist() {
    param(
        [Parameter(Mandatory = $True)]
        [array]$mainlist,

        [Parameter(Mandatory = $True)]
        [array]$sublist
    )
    [System.Collections.ArrayList]$result = @()
    foreach ($item in $sublist) {
        if (-not $mainlist.Contains($item)) {
            $result.Add($item)
        }
    }

    return [array]$result
}

function get-dependentbiztalkappsrecurse() {
    param(
        [Parameter(Mandatory = $True)]
        [string] $biztalkAppName,

        [Parameter(Mandatory = $True)]
        [string] $managmentDbServer,

        [Parameter(Mandatory = $True)]
        [string] $managementDb,

        [System.Collections.ArrayList] $dependencylist = @()
    )
    Write-Verbose "Checking dependency for $biztalkAppName on server $managmentDbServer"
    $apps = get-dependentbiztalkappslevelone $biztalkAppName $managmentDbServer $managementDb
    Write-Verbose  "Dependents for $biztalkAppName : $apps"

    #No other apps depends on this one. Time to exit..
    if ($null -eq $apps) {
        Write-Verbose "Nothing depends on $biztalkAppName , current list $dependencylist"
        if ($dependencylist.Contains($biztalkAppName)) {
            return [array] $dependencylist
        }

        $null = $dependencylist.Add($biztalkAppName)
        return [array]$dependencylist
    }

    #Ok there are other apps that depend on this one. So recurse through the dependent list
    foreach ($app in $apps) {
        $moewdpends = get-dependentbiztalkappsrecurse $app $managmentDbServer $managementDb $dependencylist
        $appsToadd = get-itemsnotinlist $dependencylist $moewdpends
        if ($appsToadd.Count -gt 0) {
            $null = $dependencylist.AddRange($appsToadd)
        }
    }

    #All depdencies added, now add the app to the list at the end
    if (-not $dependencylist.Contains($biztalkAppName)) {
        $null = $dependencylist.Add($biztalkAppName)
    }

    return [array]$dependencylist
}

Export-ModuleMember -function publish-btdfBiztalkApplication
Export-ModuleMember -function unpublish-btdfBiztalkApplication
Export-ModuleMember -function install-btdfBiztalkApp
Export-ModuleMember -function deploy-btdfBiztalkApp
Export-ModuleMember -function Start-Command
Export-ModuleMember -function Export-EnvironmentSettings
Export-ModuleMember -function Substitute-XmlSettingsFileValues