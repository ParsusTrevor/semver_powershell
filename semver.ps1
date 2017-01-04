# Credit: Marcus Andersson
# https://gist.githubusercontent.com/mckn/4136080/raw/7dc2dbaf24d4c54363ab02ac6d0a079c69e36f23/semver.ps1
# Adapted for VersionHelper in ASPNET Boilerplate
function Bump-Version
{
	param([string]$part = $(throw "Part is a required parameter."))
    
    $assemblyDirectory = "..\Acdhh\Acdhh.Core\"

	$version = Get-AssemblyInfoVersion -Directory $assemblyDirectory -GlobalAssemblyInfo $false
	$bumpedVersion = $version.PSObject.Copy();

	switch -wildcard ($part)
	{
		"ma*" { $bumpedVersion.Major = Bump-NumericVersion -Current $version.Major }
		"mi*" { $bumpedVersion.Minor = Bump-NumericVersion -Current $version.Minor }
		"p*" { $bumpedVersion.Patch = Bump-NumericVersion -Current $version.Patch }
		"b*" { $bumpedVersion.Build = Bump-SpecialVersion -Current $version.Build }
		default { throw "Parameter Part should be: minor, major, patch or build!"}
	}

	if($bumpedVersion.Major -eq $version.Major -and 
	   $bumpedVersion.Minor -eq $version.Minor -and
	   $bumpedVersion.Patch -eq $version.Patch -and
	   $bumpedVersion.Build -eq $version.build)
	{
		throw "Version didn't change due to some error..."
	}

	Update-AssemblyInfoVersion -Directory $assemblyDirectory -GlobalAssemblyInfo $false -BumpedVersion $bumpedVersion

    return New-Object PSObject -Property @{
        OldVersion = $version
        NewVersion = $bumpedVersion
    }
}

function Bump-NumericVersion
{
	param([int] $current = $(throw "Current is a required parameter."))
	return $current + 1;
}

function Bump-SpecialVersion
{
	param([string]$current = $(throw "Current is a required paramter."))

	throw "Not implemented...."
}

function Clone-Object
{
	param([PSObject] $object = $(throw "Object is a required parameter."))

	$clone = New-Object PSObject
	$object.psobject.properties | % { $clone | Add-Member -MemberType $_.MemberType -Name $_.Name -Value $_.Value }

	return $clone
}

function Get-AssemblyInfoVersion
{
	param([string] $directory = $(throw "Directory is a required parameter."),
		  [bool] $globalAssemblyInfo = $false)

	$fileName = "AppVersionHelper.cs"
	$versionPattern = 'Version = "([0-9])+\.([0-9])+\.([0-9])+\-?(.*)?"'

	if($globalAssemblyInfo)
	{
		$fileName = "GlobalAssemblyInfo.cs"
	}

	$assemblyInfo = Get-ChildItem $directory -Recurse | 
						Where-Object {$_.Name -eq $fileName} | 
						Select-Object -First 1A

	if(!$assemblyInfo)
	{
		throw "Could not find assembly info file"
	}

	$matchedLine = Get-Content $assemblyInfo.FullName |
					   Where-Object { $_ -match $versionPattern } |
					   Select-Object -First 1

	if(!$matchedLine)
	{
		throw "Could not find line containing assembly version in assembly info file"
	}					   

	$major, $minor, $patch, $build = ([regex]$versionPattern).matches($matchedLine) |
										  foreach {$_.Groups } | 
										  Select-Object -Skip 1

	$version = New-Object PSObject -Property @{
		Minor = $minor.Value
		Major = $major.Value
		Patch = $patch.Value
		Build = $build.Value
	}

	$version | add-member ScriptMethod tostring { '{0}.{1}.{2}' -f $this.major,$this.minor,$this.patch } -Force

	return $version
}

function Update-AssemblyInfoVersion
{
	param([PSObject] $bumpedVersion = $(throw "BumpedVersion is a required parameter."),
		  [string] $directory = $(throw "Directory is a required parameter."),
		  [bool] $globalAssemblyInfo = $false)

    $assemblyVersionPattern = 'Version = "([0-9])+\.([0-9])+\.([0-9])+\-?(.*)?"'
	
	$version = ("{0}.{1}.{2}" -f $bumpedVersion.Major, $bumpedVersion.Minor, $bumpedVersion.Patch)
	if($bumpedVersion.Build)
	{
		$version = "{0}-{1}" -f $version, $bumpedVersion.Build
	}

	$assemblyVersion = 'Version = "' + $version + '"'
	#$fileVersion = 'AssemblyFileVersion("' + $version + '")'

	$fileName = "AppVersionHelper.cs"
	
	Get-ChildItem $directory -Recurse -Filter $fileName | ForEach-Object {
		$currentFile = $_.FullName
		$tempFile = ("{0}.tmp" -f $_.FullName)

		Get-Content $currentFile | ForEach-Object {
			% { $_ -Replace $assemblyVersionPattern, $assemblyVersion }
			#% { $_ -Replace $assemblyFileVersionPattern, $fileVersion }
		} | Set-Content $tempFile

		Remove-Item $currentFile
		Rename-Item $tempFile $currentFile

		Write-Host "Updated version to: $version in $currentFile"
	}
}
