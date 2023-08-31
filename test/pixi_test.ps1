param(
    [Parameter(Mandatory=$false)]
    [string]$Branch = "master",
    [Parameter(Mandatory=$false)]
    [string]$RepoType = "remote",
    [Parameter(Mandatory=$false)]
    [bool]$JustSetup = $false
)

$env:PIXI_TESTING = "true"

if ($JustSetup) {
    Write-Output "Just running setup"
} else {
    Write-Output "Running full test"
}

Write-Output "Using $Branch branch"

if ( $RepoType -eq "remote" ) {
    Write-Output "Using remote repository"
    $repourl = @("https://github.com/JackTheSpades/SpriteToolSuperDelux")
}
elseif ( $RepoType -eq "local" ) {
    Write-Output "Using local repository"
    $repourl = @('..', 'SpriteToolSuperDelux')
}
else {
    Write-Output "Wrong repository type"
    exit 1
}

Invoke-WebRequest -Uri www.atarismwc.com/base.smc -OutFile base.smc

# clone current pixi repo and build zip
if ($env:ARTIFACT_PATH) {
    $artifact_path = $env:ARTIFACT_PATH
    Move-Item $artifact_path pixi.zip
} else {
    git clone $repourl
    Set-Location SpriteToolSuperDelux
    git checkout $Branch
    mkdir build
    Set-Location build
    cmake ..
    cmake --build . --config Release --target pixi
    Set-Location ..
    py zip.py
    Move-Item pixi.zip ../pixi.zip
    Set-Location ..
}

Expand-Archive pixi.zip -DestinationPath pixi

# delete temp files
if (!$env:ARTIFACT_PATH) {
    Remove-Item -Recurse -Force SpriteToolSuperDelux
}
Remove-Item pixi.zip

mkdir downloader_test
Copy-Item runner.py downloader_test/runner.py
Copy-Item downloader.py downloader_test/downloader.py
Copy-Item EXPECTED.lst downloader_test/EXPECTED.lst

# move rom and start script
Copy-Item -Recurse pixi downloader_test
Copy-Item base.smc downloader_test/pixi/base.smc
if (Test-Path -Path ".sprites_dl_cache") {
    Copy-Item -Recurse -Path .sprites_dl_cache/* -Destination downloader_test
    Set-Location downloader_test
    if (-not $JustSetup) {
        py runner.py --cached
    }
    Set-Location ..
}
else {
    mkdir .sprites_dl_cache
    Set-Location downloader_test 
    if (-not $JustSetup) {
        py runner.py
    }
    Set-Location ..
    Copy-Item -Recurse downloader_test/standard .sprites_dl_cache
    Copy-Item -Recurse downloader_test/shooter .sprites_dl_cache
    Copy-Item -Recurse downloader_test/generator .sprites_dl_cache
    Copy-Item -Recurse downloader_test/cluster .sprites_dl_cache
    Copy-Item -Recurse downloader_test/extended .sprites_dl_cache
}
if (-not $JustSetup) {
    Move-Item -Force downloader_test/result.json result.json

    Remove-Item -Recurse -Force downloader_test
    Remove-Item -Recurse -Force pixi
    Remove-Item base.smc
}