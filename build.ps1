# $ErrorActionPreference = 'Stop'
if(!$PSDefaultParameterValues['*:ErrorAction']) { $PSDefaultParameterValues['*:ErrorAction'] = 'Stop' }
Write-Output -InputObject "Script running from: $($PWD.path)"

##############################################################################################
#Region Setup variables

# When running as part of a pipeline this is executed *from* the root of the checked out
# repository. $PSScriptRoot is not populated so we can't use that. Instead, just use PWD.
$RootFolder = $PWD.path
Write-Output -InputObject "Root folder: $RootFolder"

# Our module name is the same as the project title:
# Though if we're not running in a pipeline (e.g. building locally), we'll just use the name of the root folder:
$ModuleName = $RootFolder | Split-Path -Leaf

Write-Output -InputObject "Module name: $ModuleName"

# The module code is stored in the /Source folder:
$ModuleSource = Join-Path -Path $RootFolder -ChildPath Source
Write-Output -InputObject "Module source root: $ModuleSource"
$SourceManifestFile = Join-Path -Path $ModuleSource -ChildPath "$ModuleName.psd1"

# Set the build folder equal to the module name:
$BuildFolder = Join-Path -Path $RootFolder -ChildPath $ModuleName
#EndRegion


##############################################################################################
#Region Bundle the module into a new subfolder (equal to it's name) ready for testing:
# Remove the old build folder if it exists:
if($Null -ne (Get-Item -Path $BuildFolder -ErrorAction SilentlyContinue))
{
	Write-Output -InputObject "Removing old build folder: $BuildFolder"
	Remove-Item -Path $BuildFolder -Recurse -Force | Out-Null
}

# Create a new build folder:
Write-Output -InputObject "Creating new build folder: $BuildFolder"
New-Item -Path $BuildFolder -ItemType Directory | Out-Null

# Combine the public and private functions from the source folder, into a single file:
$BuildModuleFile = Join-Path -Path $BuildFolder -ChildPath "$ModuleName.psm1"

Write-Output -InputObject "Combining public and private functions into a single file: $BuildModuleFile"
if($PSEdition -eq 'Core')
{
	# Take advantage of the new -AdditionalChildPath parameter
	$PublicFunctionPath = Join-Path -Path $ModuleSource -ChildPath "Public" -AdditionalChildPath "*.ps1"
}
else
{
	$PublicFunctionPath = Join-Path -Path (Join-Path -Path $ModuleSource -ChildPath "Public") -ChildPath "*.ps1"
}
$PublicFunctions = @( Get-ChildItem -Path $PublicFunctionPath -Recurse -ErrorAction 'SilentlyContinue' )

if($PSEdition -eq 'Core')
{
	# Take advantage of the new -AdditionalChildPath parameter
	$PrivateFunctionPath = Join-Path -Path $ModuleSource -ChildPath "Private" -AdditionalChildPath "*.ps1"
}
else
{
	$PrivateFunctionPath = Join-Path -Path (Join-Path -Path $ModuleSource -ChildPath "Private") -ChildPath "*.ps1"
}
$PrivateFunctions = @( Get-ChildItem -Path $PrivateFunctionPath -Recurse -ErrorAction 'SilentlyContinue' )

@($PublicFunctions + $PrivateFunctions) | Get-Content | Add-Content -Path $BuildModuleFile -Force

# Copy the module manifest file from the source folder to the build folder:
Write-Output -InputObject "Copying module manifest file from source folder to build folder"
Copy-Item -Path $SourceManifestFile -Destination $BuildFolder -Force

# If there are any ps1xml files in the source folder, copy them to the build folder:
$PS1XMLFiles = @( Get-ChildItem -Path $ModuleSource -Filter "*.ps1xml" -Recurse -ErrorAction 'SilentlyContinue' )
if($PS1XMLFiles.Count -gt 0)
{
	Write-Output -InputObject "Copying $($PS1XMLFiles.Count) ps1xml files from source folder to build folder"
	Copy-Item -Path $PS1XMLFiles.FullName -Destination $BuildFolder -Force
}
#EndRegion
