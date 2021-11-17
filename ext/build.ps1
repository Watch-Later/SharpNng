#! /usr/bin/env pwsh
#
# Build script for nng, building the following platforms:
#
# On Windows:
#   win-x86
#   win-x64
#   win-arm
#   win-arm64
#
# On Linux:
#   linux-x64
#   linux-arm
#   linux-arm64
#
# On Mac:
#   osx-x64
#   osx-arm64
# -------------------------------------------------------------
$ErrorActionPreference = "Stop"
Try {
$BuildFolder = "build"

# Common function used for building x86/x64/arm/arm64
function Build-Project {

    param (
        $NETArch
    )

    # Setup the correct build system and outputs based on platform
    $NETPlatform = "linux"
    $NETSharedLibExtension = "so"
    $CMakeBuilder = "Unix Makefiles"
    $CMakeArch = ""
    $BuildPlatformSubFolder = "/nng"
    if ($IsMacOS) {
        $NETPlatform = "osx"
        $NETSharedLibExtension = "dylib"
        if ($NETArch -eq "arm64") {
            $CMakeArch = "-DCMAKE_OSX_ARCHITECTURES=arm64"
        }
    }
    elseif ($IsWindows) {
        $MsvcArch = $NETArch
        if ($MsvcArch -eq "x86") {
            $MsvcArch = "win32"
        }
        $NETPlatform = "win"
        $NETSharedLibExtension = "dll"
        $CMakeBuilder = "Visual Studio 16 2019"
        $CMakeArch = "-A$MsvcArch"
        $BuildPlatformSubFolder = "/nng/Release"
    } elseif ($IsLinux) {
        if ($NETArch -eq "arm64") {
            $CMakeArch = "-DCMAKE_TOOLCHAIN_FILE=toolchains/aarch64-linux-gnu.toolchain.cmake"
        }
        elseif ($NETArch -eq "arm") {
            $CMakeArch = "-DCMAKE_TOOLCHAIN_FILE=toolchains/arm-linux-gnueabihf.toolchain.cmake"
        }
    }

    Write-Host "Building nng $NETPlatform-$NETArch" -ForegroundColor Green

    $BuildPlatformFolder = "$BuildFolder/$NETPlatform-$NETArch"
    $PackageFolder = "$BuildFolder/package/$NETPlatform-$NETArch/native/"

    & cmake -G"$CMakeBuilder" $CMakeArch -B"$BuildPlatformFolder"
    if ($LastExitCode -ne 0) {
        throw "error with cmake"
    }
    & cmake --build "$BuildPlatformFolder" --config Release
    if ($LastExitCode -ne 0) {
        throw "error with cmake --build"
    }
    
    New-Item -type Directory -Path $PackageFolder -Force
    Copy-Item "$BuildPlatformFolder$BuildPlatformSubFolder/*.$NETSharedLibExtension" -Destination $PackageFolder
}

if (Test-Path $BuildFolder) {
    Remove-Item -Path $BuildFolder -Recurse
}

if ($IsWindows) {
    Build-Project x86
}

if ($IsWindows -Or $IsMacOS -Or $IsLinux) {
    Build-Project x64
    Build-Project arm64
}

if ($IsWindows -Or $IsLinux) {
    Build-Project arm
}

} Catch {
    $message = $_.Exception | Out-String
    $line = $_.InvocationInfo.ScriptLineNumber
    Write-Host "Error at line $line : $message" -ForegroundColor Red
    exit 1
}
