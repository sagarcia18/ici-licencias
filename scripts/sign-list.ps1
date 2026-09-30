# Signs revoked.txt into revoked.json, the list the ICI_capacitacion add-in downloads.
# Output format must match RevocationList + LicenseFile in the add-in's Licensing/LicenseFormat.cs:
#   { "data": Base64(UTF-8 JSON {published, validUntil, revoked}), "signature": Base64(RSA SHA-256 PKCS#1) }
# Runs on Windows PowerShell 5.1 (local tests) and PowerShell 7 (GitHub Actions), so the JSON is
# written by hand instead of ConvertTo-Json, whose formatting differs between the two.
param(
    [int]$ValidDays = 14,
    [string]$InputPath = (Join-Path $PSScriptRoot '..\revoked.txt'),
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\revoked.json')
)

$ErrorActionPreference = 'Stop'

# Key XML comes from the environment so it never touches the repo or the command line.
$keyXml = $env:LIST_PRIVATE_KEY
if ([string]::IsNullOrWhiteSpace($keyXml)) {
    throw 'LIST_PRIVATE_KEY is not set. In GitHub: Settings > Environments > licencias > add the secret.'
}

# One fingerprint per line; blank lines and "#" comments are allowed for notes like who/when.
# A malformed line fails the run instead of being skipped: a typo must never silently leave a
# license un-revoked.
$fingerprints = New-Object System.Collections.Generic.List[string]
$lineNumber = 0
foreach ($line in [System.IO.File]::ReadAllLines($InputPath)) {
    $lineNumber++
    $entry = ($line -split '#', 2)[0].Trim().ToLowerInvariant()
    if ($entry.Length -eq 0) { continue }
    if ($entry -notmatch '^[0-9a-f]{64}$') {
        throw "revoked.txt line ${lineNumber}: '$entry' is not a 64-character hex fingerprint."
    }
    if (-not $fingerprints.Contains($entry)) { $fingerprints.Add($entry) }
}

# UTC so the date doesn't depend on the runner's time zone.
$today = [DateTime]::UtcNow.Date
$published = $today.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
$validUntil = $today.AddDays($ValidDays).ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)

$revokedJson = ($fingerprints | ForEach-Object { '"' + $_ + '"' }) -join ','
$payload = '{"published":"' + $published + '","validUntil":"' + $validUntil + '","revoked":[' + $revokedJson + ']}'
$dataBytes = [System.Text.Encoding]::UTF8.GetBytes($payload)

$rsa = [System.Security.Cryptography.RSA]::Create()
try {
    $rsa.FromXmlString($keyXml)
    $signature = $rsa.SignData($dataBytes,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
}
finally {
    $rsa.Dispose()
}

$file = "{`n  `"data`": `"$([Convert]::ToBase64String($dataBytes))`",`n  `"signature`": `"$([Convert]::ToBase64String($signature))`"`n}`n"
[System.IO.File]::WriteAllText($OutputPath, $file, (New-Object System.Text.UTF8Encoding $false))

Write-Output "Signed $($fingerprints.Count) revoked license(s); published $published, valid until $validUntil."
