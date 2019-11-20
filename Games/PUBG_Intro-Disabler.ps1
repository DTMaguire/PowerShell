# PUBG Intro Disabler
# Copyright DM Tech 2019 - Vredesbyrd Noir

try {
    $PUBGMovies = Join-Path (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 578080').InstallLocation -ChildPath '\TslGame\Content\Movies'
    Write-Output "PUBG movies path: $PUBGMovies"
    Set-Location $PUBGMovies -Verbose
}
catch {
    Write-Error -Message 'Unable to read PUBG install location from the registry.' -ErrorAction Stop
}

if (Test-Path '.\season_autoplay_film_original.mp4' -PathType Leaf) {
    Write-Warning -Message "Destination file name `'season_autoplay_film_original.mp4`' already exists." -ErrorAction Stop
    Invoke-Item $PUBGMovies
} else {
    Rename-Item 'season_autoplay_film.mp4' -NewName 'season_autoplay_film_original.mp4' -Verbose
    Copy-Item 'LoadingScreen.mp4' -Destination 'season_autoplay_film.mp4' -Verbose
}

Write-Host "Press any key to close window..."
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Winner winner, no fucking loud PUBG intro video!
