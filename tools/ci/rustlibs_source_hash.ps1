# Prints a hash of the Rust code that rustlibs.dll, rustlibs_prod.dll and tools/ci/librustlibs_ci.so are built from.
# The !build_rust bot saves it in tools/ci/rustlibs_source_hash.txt every time it builds them.
# With -Check it compares instead, and fails if the Rust code changed since the libraries were built.
# CI and the Windows TGS deploy script (tools/tgs_scripts/PreCompile.bat) both run it with -Check.
# Line endings and readmes don't change the hash, so every checkout gets the same one. Works on Windows PowerShell 5.1 and pwsh.
param(
	[string]$Root = (Join-Path $PSScriptRoot "../.."),
	[switch]$Check
)
$ErrorActionPreference = "Stop"

$rust_dir = (Resolve-Path (Join-Path $Root "rust")).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)
$sha = [System.Security.Cryptography.SHA256]::Create()

function Get-Hex([byte[]]$bytes) {
	return ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
}

# Every file in rust/ except build output and readmes, sorted the same way on every system
[string[]]$files = Get-ChildItem -Path $rust_dir -Recurse -File -Force |
	ForEach-Object { $_.FullName.Substring($rust_dir.Length + 1).Replace("\", "/") } |
	Where-Object { -not $_.StartsWith("target/") -and -not ((Split-Path $_ -Leaf) -like "readme*") }
[Array]::Sort($files, [StringComparer]::Ordinal)

$lines = foreach($file in $files) {
	$text = [System.IO.File]::ReadAllText((Join-Path $rust_dir $file), $utf8).Replace("`r`n", "`n")
	"$file $(Get-Hex $sha.ComputeHash($utf8.GetBytes($text)))"
}
$hash = Get-Hex $sha.ComputeHash($utf8.GetBytes(($lines -join "`n") + "`n"))

if(-not $Check) {
	Write-Output $hash
	exit 0
}

$error_prefix = ""
if($env:GITHUB_ACTIONS -eq "true") {
	$error_prefix = "::error::"
}
$hash_file = Join-Path $Root "tools/ci/rustlibs_source_hash.txt"
if(-not (Test-Path $hash_file)) {
	Write-Output "tools/ci/rustlibs_source_hash.txt doesn't exist, so the Rust libraries can't be checked."
	exit 0
}
$built_from = (Get-Content $hash_file -Raw).Trim()
if($built_from -ne $hash) {
	Write-Output "$($error_prefix)The Rust code changed, but rustlibs.dll, rustlibs_prod.dll and tools/ci/librustlibs_ci.so weren't rebuilt from it. A maintainer needs to comment !build_rust on the pull request (merge master into it first if master's Rust code changed too)."
	exit 1
}
Write-Output "The Rust libraries were built from this Rust code."
exit 0
