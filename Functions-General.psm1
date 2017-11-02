# $TemplateObject = Get-Content -Raw -Path $VmDynamicTemplateFile | ConvertFrom-Json

function Get-TemplateMap()
{
  $templateMapFile = ".\template.map.json"

  if(-Not (Test-Path $templateMapFile))
  {
    throw [System.IO.FileNotFoundException] "Template map file not found [$($templateMapFile)]."
  }

  $map = Get-Content -Raw -Path $templateMapFile | ConvertFrom-Json

  foreach( $mapItem in $map )
  {
    if( -Not (Get-Member -InputObject $mapItem -Name "displayName" -MemberType Properties) )
    {
      throw "Template map is not in the expected format, missing [ displayName ] on object"
    }
    if( -Not (Get-Member -InputObject $mapItem -Name "shortName" -MemberType Properties) )
    {
      throw "Template map is not in the expected format, missing [ shortName ] on object"
    }
    if( -Not (Get-Member -InputObject $mapItem -Name "platformType" -MemberType Properties) )
    {
      throw "Template map is not in the expected format, missing [ platformType ] on object"
    }
    if( -Not (Get-Member -InputObject $mapItem -Name "dynamicTemplate" -MemberType Properties) )
    {
      throw "Template map is not in the expected format, missing [ dynamicTemplate ] on object"
    }
    if( -Not (Get-Member -InputObject $mapItem -Name "staticTemplate" -MemberType Properties) )
    {
      throw "Template map is not in the expected format, missing [ staticTemplate ] on object"
    }
  }

  return $Map
}

function Get-TemplateShortNames()
{
  $map = Get-TemplateMap
  $shortNames = @()

  foreach($mapItem in $map)
  {
    if( $mapItem.shortName -eq "storage" )
    { # Don't return the storage account template in the selectable list
      continue
    }
    $shortNames += $mapItem.shortName
  }

  return $shortNames
}

function Get-TemplateByShortName( $ShortName )
{
  $template = $null

  $map = Get-TemplateMap
  foreach($mapItem in $map)
  {
    if( $mapItem.shortName.ToLower() -eq $ShortName.ToLower() )
    {
      $template = $mapItem
      break
    }
  }

  if( $template -eq $null )
  {
    throw "No platform template found for the requested name [ $($ShortName) ]"
  }

  return $template
}

function Get-ResolvedTemplatePath( $TemplateFile )
{
  $TemplatePath = $null

  if( Test-Path $TemplateFile )
  {
    $TemplatePath = $TemplateFile
  }
  elseif ( Test-Path ".\templates\$($TemplateFile)" )
  {
    $TemplatePath  = ".\templates\$($TemplateFile)"
  }
  else
  {
    throw "The template file specifed [ $($TemplateFile) ] could not be found"
  }

  return $TemplatePath
}

function Get-TemplateObjectFromFile( $TemplateFile )
{
  $TemplatePath = Get-ResolvedTemplatePath -TemplateFile $TemplateFile
  return Get-Content -Raw -Path $TemplatePath | ConvertFrom-Json
}

function Select-Platform( )
{
  $templatesAll = Get-TemplateMap
  $templates = @()

  foreach( $template in $templatesAll )
  {
    if( $template.platformType -eq "storage" )
    {
      continue
    }
    $templates += $template
  }

  $SelectedIndex = 0
  for( $i = 0; $i -lt $templates.Length; $i++ )
  {
    Write-Host "$($i+1)) $($templates[$i].displayName) ($($templates[$i].shortName))"
  }
  $SelectedIndex = Read-Host "Select a platform"

  return $templates[$SelectedIndex-1].shortName
}