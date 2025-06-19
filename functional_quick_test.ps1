# Load functional tool management
# . "E:\tools\functional_tool_manager.ps1"

# Functional configuration parsing
function Get-QuickTestConfig {
    param([string]$ConfigPath)
    
    Get-Content $ConfigPath | 
    Group-Object { if ($_ -match "^# (.+)$") { $Matches[1] } else { "CURRENT" } } |
    Where-Object { $_.Name -ne "CURRENT" } |
    ForEach-Object {
        @{
            Section = $_.Name
            Data = switch ($_.Name) {
                "QUICK_TEST_PLATFORMS" { 
                    $_.Group | Where-Object { $_ -notmatch "^#" } | ConvertTo-PlatformConfig 
                }
                "IMAGE_SIGNATURES" { 
                    $_.Group | Where-Object { $_ -notmatch "^#" } | ConvertTo-ImageSignatures 
                }
                default { 
                    ($_.Group | Where-Object { $_ -notmatch "^#" }) -split "," | ForEach-Object { $_.Trim() }
                }
            }
        }
    }
}

function ConvertTo-PlatformConfig {
    param([Parameter(ValueFromPipeline)]$Line)
    
    process {
        $parts = $Line -split "\|"
        if ($parts.Count -eq 2) {
            @{
                Name = $parts[0].Trim()
                Domains = $parts[1] -split "," | ForEach-Object { $_.Trim() }
            }
        }
    }
}

function ConvertTo-ImageSignatures {
    param([Parameter(ValueFromPipeline)]$Line)
    
    process {
        $parts = $Line -split "\|"
        if ($parts.Count -ge 4) {
            @{
                Name = $parts[0].Trim()
                Bytes = ($parts[1].Trim() -split " " | ForEach-Object { [Convert]::ToByte($_, 16) })
                Extension = $parts[2].Trim()
                MinOffset = [int]$parts[3].Trim()
                MaxOffset = if ($parts.Count -gt 4) { [int]$parts[4].Trim() } else { [int]$parts[3].Trim() }
            }
        }
    }
}

# Pure functions for image analysis
function Test-ImageSignature {
    param([byte[]]$Bytes, [hashtable]$Signature)
    
    if ($Bytes.Length -lt ($Signature.MinOffset + $Signature.Bytes.Length)) {
        return $null
    }
    
    for ($offset = $Signature.MinOffset; $offset -le $Signature.MaxOffset; $offset++) {
        if (($offset + $Signature.Bytes.Length) -gt $Bytes.Length) { break }
        
        $match = $true
        for ($i = 0; $i -lt $Signature.Bytes.Length; $i++) {
            if ($Bytes[$offset + $i] -ne $Signature.Bytes[$i]) {
                $match = $false
                break
            }
        }
        
        if ($match) {
            return @{
                SignatureName = $Signature.Name
                Extension = $Signature.Extension
                FoundAt = $offset
                IsImage = $true
            }
        }
    }
    
    return $null
}

function Get-ImageAnalysis {
    param([string]$FilePath, [hashtable[]]$ImageSignatures)
    
    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        
        $imageSignatures | ForEach-Object {
            Test-ImageSignature $bytes $_
        } | Where-Object { $_ } | Select-Object -First 1
        
    } catch {
        $null
    }
}

# Functional cache image extraction
function Get-CachedImages {
    param(
        [string]$CacheDirectory,
        [hashtable[]]$ImageSignatures,
        [string]$OutputDirectory,
        [int]$MinSize = 5000,
        [int]$MaxFiles = 2000
    )
    
    if (-not (Test-Path $CacheDirectory)) { return @() }
    
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    
    Get-ChildItem $CacheDirectory -File | 
    Select-Object -First $MaxFiles |
    ForEach-Object {
        $analysis = Get-ImageAnalysis $_.FullName $ImageSignatures
        if ($analysis -and $_.Length -gt $MinSize) {
            $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
            $hash = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new($bytes)) -Algorithm MD5).Hash
            $outputPath = Join-Path $OutputDirectory "$hash$($analysis.Extension)"
            
            Copy-Item $_.FullName $outputPath
            
            @{
                OriginalFile = $_.FullName
                OutputFile = $outputPath
                ImageType = $analysis.SignatureName
                Size = $_.Length
                Hash = $hash
            }
        }
    } | Where-Object { $_ }
}

# Functional browser history analysis
function Get-BrowserHistoryStats {
    param([string]$HistoryDbPath, [string]$SqliteExe)
    
    if (-not (Test-Path $HistoryDbPath) -or -not $SqliteExe) {
        return $null
    }
    
    try {
        $totalQuery = "SELECT COUNT(*) FROM urls;"
        $totalUrls = & $SqliteExe $HistoryDbPath $totalQuery
        
        @{
            Success = $true
            TotalUrls = $totalUrls
            DatabasePath = $HistoryDbPath
        }
    } catch {
        @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Functional platform analysis
function Get-PlatformActivity {
    param(
        [string]$HistoryDbPath,
        [string]$SqliteExe,
        [hashtable[]]$Platforms,
        [string[]]$SuspiciousDomains = @()
    )
    
    if (-not (Test-Path $HistoryDbPath) -or -not $SqliteExe) {
        return @()
    }
    
    # Platform activity
    $platformActivity = $Platforms | ForEach-Object {
        $platform = $_
        $domainConditions = $platform.Domains | ForEach-Object { "url LIKE '%$_%'" }
        $whereClause = $domainConditions -join " OR "
        $query = "SELECT COUNT(*) FROM urls WHERE $whereClause;"
        
        try {
            $count = & $SqliteExe $HistoryDbPath $query
            @{
                Platform = $platform.Name
                VisitCount = [int]$count
                Type = "Platform"
            }
        } catch {
            @{
                Platform = $platform.Name
                VisitCount = 0
                Type = "Platform"
                Error = $_.Exception.Message
            }
        }
    }
    
    # Suspicious domain activity
    $suspiciousActivity = $SuspiciousDomains | ForEach-Object {
        $domain = $_
        $query = "SELECT COUNT(*) FROM urls WHERE url LIKE '%$domain%';"
        
        try {
            $count = & $SqliteExe $HistoryDbPath $query
            if ($count -gt 0) {
                @{
                    Platform = $domain
                    VisitCount = [int]$count
                    Type = "Suspicious"
                }
            }
        } catch {
            # Silently continue
        }
    } | Where-Object { $_ }
    
    $platformActivity + $suspiciousActivity
}

# Functional email contact extraction
function Get-EmailContacts {
    param([string]$StorageDirectory, [string[]]$EmailPatterns)
    
    if (-not (Test-Path $StorageDirectory)) { return @() }
    
    Get-ChildItem $StorageDirectory -File |
    ForEach-Object {
        try {
            $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { return }
            
            $hasEmailData = $EmailPatterns | Where-Object { $content -match $_ } | Select-Object -First 1
            
            if ($hasEmailData) {
                $emailPattern = '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
                $emails = [regex]::Matches($content, $emailPattern) | ForEach-Object { $_.Value }
                
                if ($emails.Count -gt 0) {
                    @{
                        SourceFile = $_.Name
                        Emails = $emails | Sort-Object -Unique
                        EmailCount = $emails.Count
                    }
                }
            }
        } catch {
            # Continue silently
        }
    } | Where-Object { $_ }
}

# Main functional test pipeline
function Invoke-FunctionalQuickTest {
    param(
        [string]$ConfigPath = "E:\tools\quick_test_config.txt",
        [string]$OutputDirectory = "E:\QUICK_EVIDENCE",
        [string]$EdgeProfile = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default",
        $GetToolFunction
    )
    
    Write-Host "🚀 