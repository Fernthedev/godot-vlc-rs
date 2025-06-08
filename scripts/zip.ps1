#!/bin/pwsh
param (
    [string]$ProjectRoot = "."
)

function Get-Platform {
    if ($IsWindows) { return "windows" }
    elseif ($IsMacOS) { return "macos" }
    elseif ($IsLinux) { return "linux" }
    else { throw "Unsupported OS" }
}

function Get-LibraryFile {
    param($platform, $targetSuffix)

    switch ($platform) {
        "windows" { return "godot_vlc$($targetSuffix).dll" }
        "linux"   { return "libgodot_vlc$($targetSuffix).so" }
        "macos"   { return "libgodot_vlc$($targetSuffix).dylib" }
    }
}

function Get-PlatformDir {
    param($platform)

    switch ($platform) {
        "windows" { return "win64" }
        "linux"   { return "linux_x64" }
        "macos"   { return "macos" }
    }
}


cargo build
cargo build --release

$platform = Get-Platform
$platformDir = Get-PlatformDir -platform $platform 
$binDir = Join-Path $ProjectRoot "demo/addons/godot-vlc/bin/$platformDir"
$pluginsDir = Join-Path $binDir "plugins"

$debugDir = Join-Path $ProjectRoot "target/debug"
$releaseDir = Join-Path $ProjectRoot "target/release"

# Create output directory
New-Item -Force -ItemType Directory -Path $binDir | Out-Null
New-Item -Force -ItemType Directory -Path $pluginsDir | Out-Null

# Copy GDExtension library
$libFile = Get-LibraryFile -platform $platform -targetSuffix ""
$libDebugFile = Get-LibraryFile -platform $platform -target "_debug"

$srcReleaseLib = Join-Path $releaseDir $libFile
$srcDebugLib = Join-Path $debugDir $libFile

$dstReleaseLib = Join-Path $binDir $libFile
$dstDebugLib = Join-Path $binDir $libDebugFile
Write-Host "Source library path: $srcReleaseLib $srcDebugLib"
Write-Host "Destination library path: $dstReleaseLib $dstDebugLib"

Copy-Item $srcReleaseLib -Destination $dstReleaseLib -Force
Copy-Item $srcDebugLib -Destination $dstDebugLib -Force

# Copy VLC files (update paths if needed)
switch ($platform) {
    "windows" {
        $vlcRoot = "C:\Program Files\VideoLAN\VLC"
        Copy-Item "$vlcRoot\libvlc.dll" -Destination $binDir -Force
        Copy-Item "$vlcRoot\libvlccore.dll" -Destination $binDir -Force
        Copy-Item "$vlcRoot\plugins\*" -Destination $pluginsDir -Recurse -Force
        
    }
    "linux" {
        $vlcRoot = "/usr/lib/x86_64-linux-gnu/vlc"  # /usr/lib or /usr/lib/x86_64-linux-gnu depending on distro
        Copy-Item "/usr/lib/libvlc.so*" -Destination $binDir -Force
        Copy-Item "/usr/lib/libvlccore.so*" -Destination $binDir -Force
        Copy-Item "/usr/lib/x86_64-linux-gnu/libvlc*" -Destination $binDir -Force
        Copy-Item "/usr/lib/x86_64-linux-gnu/libvlccore*" -Destination $binDir -Force
        Copy-Item "$vlcRoot/libvlc*" -Destination $binDir -Force
        Copy-Item "$vlcRoot/libvlccore*" -Destination $binDir -Force
        Copy-Item "$vlcRoot/plugins/*" -Destination $pluginsDir -Force

        #Copy-Item "/usr/lib/vlc/plugins/*" -Destination $pluginsDir -Recurse -Force
        #Copy-Item "/usr/lib/x86_64-linux-gnu/vlc/plugins/*" -Destination $pluginsDir -Recurse -Force
    }
    "macos" {
        $vlcRoot = "/Applications/VLC.app/Contents/MacOS/lib"
        Copy-Item "$vlcRoot/libvlc.dylib" -Destination $binDir -Force
        Copy-Item "$vlcRoot/libvlccore.dylib" -Destination $binDir -Force
        Copy-Item "/Applications/VLC.app/Contents/MacOS/plugins/*" -Destination $pluginsDir -Recurse -Force
    }
}

Write-Host "✅ GDExtension addon prepared for $platform in release mode."

# now make a zip file
$zipFileName = "godot-vlc-$platform-release.zip"
$zipFilePath = Join-Path $ProjectRoot "target" $zipFileName
if (Test-Path $zipFilePath) {
    Remove-Item $zipFilePath -Force
}




# include hidden
Add-Type -AssemblyName System.IO.Compression.FileSystem

[System.IO.Compression.ZipFile]::CreateFromDirectory(
    "demo/addons",
    "$zipFilePath"
)
# Compress-Archive -Path demo/addons/* -DestinationPath $zipFilePath
Write-Host "✅ Created zip file: $zipFilePath"