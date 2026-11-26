[CmdletBinding()]
param(
    [string] $GameDirectory = (Join-Path ${env:ProgramFiles(x86)} 'Steam/steamapps/common/Age of Mythology Retold'),
    [string] $GameProfile
)

$ErrorActionPreference = 'Stop'
$gameAi = Join-Path $GameDirectory 'game/ai/human_assist/human_assist.xs'
$gameMap = Join-Path $GameDirectory 'game/random_maps/alfheim.xs'
if (-not (Test-Path -LiteralPath $gameAi -PathType Leaf)) {
    throw "O script oficial de assistência não foi encontrado em $GameDirectory."
}
if (-not (Test-Path -LiteralPath $gameMap -PathType Leaf)) {
    throw "O mapa nativo Alfheim não foi encontrado em $GameDirectory."
}

if (-not $GameProfile) {
    $profileRoot = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Games/Age of Mythology Retold'
    $profiles = @(Get-ChildItem -LiteralPath $profileRoot -Directory | Where-Object {
        $_.Name -match '^\d{17}$' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'mods/local'))
    })
    if ($profiles.Count -ne 1) {
        throw 'Informe a pasta do perfil local do AoMR com -GameProfile.'
    }
    $GameProfile = $profiles[0].FullName
}

$local = (Resolve-Path -LiteralPath (Join-Path $GameProfile 'mods/local')).Path
$mod = Join-Path $local 'Gaia Autoplay'
$destination = Join-Path $mod 'game/ai/human_assist'
$maps = Join-Path $mod 'game/random_maps'
$profileFile = Join-Path $GameProfile 'users/UserProfile.xml'
$portuguese = (Test-Path -LiteralPath $profileFile) -and
    ([IO.File]::ReadAllText($profileFile) -match '<setting name="optionlanguage">8</setting>')
$original = [IO.File]::ReadAllText($gameAi)
if ($original -notmatch 'bool\s+gEnabled\b' -or $original -notmatch 'void\s+enableVillagerAssist\s*\(') {
    throw 'O script oficial mudou. Confira a integração com a versão instalada antes de atualizar o mod.'
}

$gatheringHooks = 'void\s+(?:setDistributionNumbers\(int food = 0, int wood = 0, int gold = 0\)|disableVillagerAssist\(\))\s*\{(?=\s*//)'
if ([regex]::Matches($original, $gatheringHooks).Count -ne 2) {
    throw 'As funcoes de prioridade do aldeao mudaram na versao instalada.'
}
$original = [regex]::Replace($original, $gatheringHooks, { param($match)
    $match.Value + "`r`n   gaiaGatheringRevision++;"
})
$original = "int gaiaGatheringRevision = 0;`r`n" + $original

$scoutHook = '(void enableAutoScouting\(int unitID = -1\)\s*\{\s*//[^\r\n]+\s+xsSetContextPlayer\(cMyID\);)'
if ([regex]::Matches($original, $scoutHook).Count -ne 1) {
    throw 'A funcao de exploracao automatica mudou na versao instalada.'
}
$original = [regex]::Replace($original, $scoutHook, { param($match)
    $match.Value + "`r`n   if (gaiaBotToggleCenter(unitID))`r`n   {`r`n      xsSetContextPlayer(-1);`r`n      return;`r`n   }"
})
$original = "mutable bool gaiaBotToggleCenter(int unitID = -1) { return false; }`r`n" + $original

if (-not ('GaiaTownCenterCommands' -as [type])) {
    Add-Type -Path (Join-Path $PSScriptRoot 'TownCenterCommands.cs')
}
[GaiaTownCenterCommands]::Install((Join-Path $GameDirectory 'game/data/Data.bar'), (Join-Path $mod 'game/data'), $portuguese)

# Remove only the generated HUD overrides from earlier versions.
$previousOverrides = @{
    'HUD.xaml' = 'x:Name="GaiaAutoplayButton"'
    'VillagerPrioritiesPopup.xaml' = 'Content="Gaia Autoplay (Gaia) /'
}
foreach ($name in $previousOverrides.Keys) {
    $file = Join-Path $mod "game/ui_myth/content/ingame/$name"
    if ((Test-Path -LiteralPath $file -PathType Leaf) -and
        [IO.File]::ReadAllText($file).Contains($previousOverrides[$name])) {
        Remove-Item -LiteralPath $file
    }
}

New-Item -ItemType Directory -Path $destination,$maps -Force | Out-Null
$encoding = [Text.UTF8Encoding]::new($false)
$script = Join-Path $PSScriptRoot 'gaia_autoplay.xs'
Copy-Item -LiteralPath $script -Destination (Join-Path $destination 'gaia_autoplay.xs') -Force
foreach ($file in 'gaia_autoplay_coop.xs','gaia_autoplay_coop.xml') {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $maps $file) -Force
}
# XS parses includes before the parent script's globals are available.
$combined = $original.TrimEnd() + "`r`n`r`n" + [IO.File]::ReadAllText($script)
[IO.File]::WriteAllText((Join-Path $destination 'human_assist.xs'), $combined, $encoding)
Write-Output "Gaia Autoplay instalado em $mod"
