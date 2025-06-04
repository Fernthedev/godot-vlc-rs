param (
    [string]$ProjectRoot = ".",
    [string]$Target = "release"  # or "debug"
)

function Get-Platform {
    if ($IsWindows) { return "windows" }
    elseif ($IsMacOS) { return "macos" }
    elseif ($IsLinux) { return "linux" }
    else { throw "Unsupported OS" }
}

function Get-LibraryFile {
    param($platform, $target)

    switch ($platform) {
        "windows" { return "godot_vlc$($targetSuffix).dll" }
        "linux"   { return "libgodot_vlc$($targetSuffix).so" }
        "macos"   { return "libgodot_vlc$($targetSuffix).dylib" }
    }
}

# run cargo build -r
$buildCommand = "cargo build --release"
if ($Target -eq "debug") {
    $buildCommand = "cargo build --features debug"
}
Write-Host "Running: $buildCommand"
Invoke-Expression $buildCommand

$platform = Get-Platform
$targetSuffix = if ($Target -eq "debug") { "_debug" } else { "" }
$binDir = Join-Path $ProjectRoot "demo/addons/godot-vlc/bin/$platform"
$pluginsDir = Join-Path $binDir "plugins"
$targetDir = Join-Path $ProjectRoot "target/$Target"

# Create output directory
New-Item -Force -ItemType Directory -Path $binDir | Out-Null
New-Item -Force -ItemType Directory -Path $pluginsDir | Out-Null

# Copy GDExtension library
$libFile = Get-LibraryFile -platform $platform -target $Target
$srcLib = Join-Path $targetDir $libFile
$dstLib = Join-Path $binDir $libFile
Copy-Item $srcLib -Destination $dstLib -Force

# Copy VLC files (update paths if needed)
switch ($platform) {
    "windows" {
        $vlcRoot = "C:\Program Files\VideoLAN\VLC"
        Copy-Item "$vlcRoot\libvlc.dll" -Destination $binDir -Force
        Copy-Item "$vlcRoot\libvlccore.dll" -Destination $binDir -Force
        Copy-Item "$vlcRoot\plugins\*" -Destination $pluginsDir -Recurse -Force
    }
    "linux" {
        $vlcRoot = "/usr/lib"  # or /usr/lib/x86_64-linux-gnu depending on distro
        Copy-Item "$vlcRoot/libvlc.so*" -Destination $binDir -Force
        Copy-Item "$vlcRoot/libvlccore.so*" -Destination $binDir -Force
        Copy-Item "/usr/lib/vlc/plugins/*" -Destination $pluginsDir -Recurse -Force
    }
    "macos" {
        $vlcRoot = "/Applications/VLC.app/Contents/MacOS/lib"
        Copy-Item "$vlcRoot/libvlc.dylib" -Destination $binDir -Force
        Copy-Item "$vlcRoot/libvlccore.dylib" -Destination $binDir -Force
        Copy-Item "/Applications/VLC.app/Contents/MacOS/plugins/*" -Destination $pluginsDir -Recurse -Force
    }
}

Write-Host "✅ GDExtension addon prepared for $platform in $Target mode."

# now make a zip file
$zipFileName = "godot-vlc-$platform-$Target.zip"
$zipFilePath = Join-Path $ProjectRoot "target" $zipFileName
if (Test-Path $zipFilePath) {
    Remove-Item $zipFilePath -Force
}
Compress-Archive -Path $binDir, $pluginsDir -DestinationPath $zipFilePath
Write-Host "✅ Created zip file: $zipFilePath"