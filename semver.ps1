# Modified From here: https://gist.githubusercontent.com/mckn/4136080/raw/7dc2dbaf24d4c54363ab02ac6d0a079c69e36f23/semver.ps1
# 
function Bump-Version
{
	param([string]$part = $(throw "Part is a required parameter."),
         $version)

	$bumpedVersion = Make-Semver -CopyFrom $version

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

	return $bumpedVersion
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

function Make-Semver
{
    param([PSObject] $CopyFrom = $null)

    if ($CopyFrom -ne $null) {
        $clone = Clone-Object $CopyFrom
    } 
    else {
        $clone = New-Object PSObject -Property @{
		    Minor = 0
		    Major = 0
		    Patch = 0
		    Build = 0
	    }
    }

    # override tostring
    $clone | add-member scriptmethod tostring { "{0}.{1}.{2}-{3}" -f $this.major,$this.Minor,$this.patch,$this.Build } -force

    return $clone
}

function Clone-Object
{
	param([PSObject] $object = $(throw "Object is a required parameter."))

	$clone = New-Object PSObject
	$object.psobject.properties | % { $clone | Add-Member -MemberType $_.MemberType -Name $_.Name -Value $_.Value }

	return $clone
}

function Get-Semver
{
    param([string] $version = $(throw "Requires a string to parse"))
    
	$versionPattern = '([0-9]+)\.([0-9]+)\.([0-9]+)\-?(.*)?'
    
	$major, $minor, $patch, $build = ([regex]$versionPattern).matches($version) |
										  foreach {$_.Groups } | 
										  Select-Object -Skip 1

    $obj = New-Object PSObject -Property @{
		Minor = $minor.Value
		Major = $major.Value
		Patch = $patch.Value
		Build = $build.Value
	}

    # override tostring
    $obj | add-member scriptmethod tostring { "{0}.{1}.{2}-{3}" -f $this.major,$this.Minor,$this.patch,$this.Build } -force
    
	return $obj
}

function Get-AssemblyInfoVersion
{
	param([string] $directory = $(throw "Directory is a required parameter."),
		  [bool] $globalAssemblyInfo = $false)

	$fileName = "AssemblyInfo.cs"
	$versionPattern = 'AssemblyVersion\("([0-9])+\.([0-9])+\.([0-9])+\-?(.*)?"\)'

	if($globalAssemblyInfo)
	{
		$fileName = "GlobalAssemblyInfo.cs"
	}

	$assemblyInfo = Get-ChildItem $directory -Recurse | 
						Where-Object {$_.Name -eq $fileName} | 
						Select-Object -First 1

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

    return Get-Semver $matchedLine
}

function Update-AssemblyInfoVersion
{
	param([PSObject] $bumpedVersion = $(throw "BumpedVersion is a required parameter."),
		  [string] $directory = $(throw "Directory is a required parameter."),
		  [bool] $globalAssemblyInfo = $false)

	$assemblyVersionPattern = 'AssemblyVersion\("([0-9])+\.([0-9])+\.([0-9])+\-?(.*)?"\)'
	$assemblyFileVersionPattern = 'AssemblyFileVersion\("([0-9])+\.([0-9])+\.([0-9])+\-?(.*)?"\)'

	$version = ("{0}.{1}.{2}" -f $bumpedVersion.Major, $bumpedVersion.Minor, $bumpedVersion.Patch)
	if($bumpedVersion.Build)
	{
		$version = "{0}-{1}" -f $version, $bumpedVersion.Build
	}

	$assemblyVersion = 'AssemblyVersion("' + $version + '")'
	$fileVersion = 'AssemblyFileVersion("' + $version + '")'

	$fileName = "AssemblyInfo.cs"
	if($globalAssemblyInfo)
	{
		$fileName = "GlobalAssemblyInfo.cs"
	}

	Get-ChildItem $directory -Recurse -Filter $fileName | ForEach-Object {
		$currentFile = $_.FullName
		$tempFile = ("{0}.tmp" -f $_.FullName)

		Get-Content $currentFile | ForEach-Object {
			% { $_ -Replace $assemblyVersionPattern, $assemblyVersion } |
			% { $_ -Replace $assemblyFileVersionPattern, $fileVersion }
		} | Set-Content $tempFile

		Remove-Item $currentFile
		Rename-Item $tempFile $currentFile

		Write-Host "Updated version to: $version in $currentFile"
	}
}
