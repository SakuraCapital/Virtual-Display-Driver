# Build Driver Package From Source

This guide explains how to build driver package materials from this repository.

Scope of this document:

- Build `MttVDD.dll` from source
- Generate `mttvdd.cat` with `Inf2Cat`
- Test-sign and verify catalog signature
- Produce package files in `Virtual Display Driver (HDR)\MttVDD\x64\Release\MttVDD`

Out of scope:

- Driver installation
- Device node creation
- Runtime display validation

## Prerequisites

- Windows 10/11
- PowerShell (Run as Administrator)
- Visual Studio 2022 with C++ build tools
- ATL/MFC components for `MSVC v143` (x64/x86)
- Windows Driver Kit (WDK) + Windows SDK

Recommended baseline (validated):

- VS 2022 Community + MSVC v143
- WDK/SDK 10.0.26100.x

## Package Layout

After successful execution, package materials are located in:

`Virtual Display Driver (HDR)\MttVDD\x64\Release\MttVDD`

Expected files:

- `MttVDD.inf`
- `MttVDD.dll`
- `mttvdd.cat`
- `vdd_settings.xml`

## One-Command Build

From repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-sign-package.ps1
```

### Optional Parameters

```powershell
# Build only, skip signing
powershell -ExecutionPolicy Bypass -File .\scripts\build-sign-package.ps1 -NoSign

# Reuse existing build artifacts, regenerate package/sign only
powershell -ExecutionPolicy Bypass -File .\scripts\build-sign-package.ps1 -NoBuild

# Custom test certificate subject
powershell -ExecutionPolicy Bypass -File .\scripts\build-sign-package.ps1 -CertSubject "MyTeam VDD Test"

# Custom Inf2Cat OS target
powershell -ExecutionPolicy Bypass -File .\scripts\build-sign-package.ps1 -Inf2CatOs "10_x64"
```

## How The Script Works

1. Builds `MttVDD.vcxproj` (`Release|x64`) unless `-NoBuild` is used.
2. Copies built `INF/DLL` and repository `vdd_settings.xml` into package directory.
3. Generates `mttvdd.cat` via `Inf2Cat` if catalog is missing.
4. Creates/reuses test certificate in `LocalMachine\My`.
5. Signs and verifies catalog unless `-NoSign` is used.

## Common Errors

### `LNK1104: cannot open file 'atls.lib'`

Install ATL/MFC components for `MSVC v143 (x64/x86)` in Visual Studio Installer.

### `MSB8036: Windows SDK version ... not found`

Install required Windows SDK/WDK version or retarget project SDK.

### `INF does not contain digital signature information`

The catalog is missing or unsigned. Re-run script without `-NoSign` and verify `mttvdd.cat` exists in package directory.

### `SignTool Error: File not found ... mttvdd.cat`

Catalog was not generated in package directory. Re-run script and ensure `Inf2Cat` succeeds.

## Notes

- Test-signing is for development/testing only.
- Production signing/release process is intentionally out of scope of this document.
