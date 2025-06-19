# Functional Configuration Parser
function Get-ToolConfiguration {
    param([string]$ConfigPath)
    
    $lines = Get-Content $ConfigPath | Where-Object { $_ -and $_ -notmatch "^\s*$" }
    
    $lines | Group-Object { 
        if ($_ -match "^# (.+)$") { $Matches[1] } else { "CURRENT" }
    } | ForEach-Object {
        $sectionName = $_.Name
        $sectionLines = $_.Group | Where-Object { $_ -notmatch "^#" }
        
        @{
            Section = $sectionName
            Data = switch ($sectionName) {
                "REQUIRED_TOOLS" { $sectionLines | ConvertTo-ToolDefinitions }
                "OPTIONAL_TOOLS" { $sectionLines | ConvertTo-ToolDefinitions }
                "TOOL_VERIFICATION" { $sectionLines | ConvertTo-VerificationCommands }
                default { $sectionLines }
            }
        }
    } | Where-Object { $_.Section -ne "CURRENT" }
}

function ConvertTo-ToolDefinitions {
    param([Parameter(ValueFromPipeline)]$Line)
    
    process {
        $parts = $Line -split "\|"
        if ($parts.Count -ge 6) {
            @{
                Name = $parts[0].Trim()
                DownloadUrl = $parts[1].Trim()
                TargetPath = $parts[2].Trim()
                ExtractionMethod = $parts[3].Trim()
                VerifyFile = $parts[4].Trim()
                Description = $parts[5].Trim()
            }
        }
    }
}

function ConvertTo-VerificationCommands {
    param([Parameter(ValueFromPipeline)]$Line)
    
    process {
        $parts = $Line -split "\|"
        if ($parts.Count -eq 2) {
            @{
                Tool = $parts[0].Trim()
                Command = $parts[1].Trim()
            }
        }
    }
}

# Pure functions for tool operations
function Test-ToolPresence {
    param([string]$Path)
    Test-Path $Path
}

function Test-ToolFunctionality {
    param([string]$Command)
    
    try {
        $result = Invoke-Expression "$Command 2>$null"
        $LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null
    } catch {
        $false
    }
}

function Get-ToolStatus {
    param(
        [hashtable]$Tool,
        [string]$VerificationCommand = $null
    )
    
    $isPresent = Test-ToolPresence $Tool.TargetPath
    $isWorking = if ($isPresent -and $VerificationCommand) { 
        Test-ToolFunctionality $VerificationCommand 
    } else { 
        $isPresent 
    }
    
    @{
        Name = $Tool.Name
        Present = $isPresent
        Working = $isWorking
        Path = $Tool.TargetPath
        Description = $Tool.Description
        Status = switch ($true) {
            ($isPresent -and $isWorking) { "READY" }
            ($isPresent -and -not $isWorking) { "PRESENT_NOT_WORKING" }
            default { "MISSING" }
        }
    }
}

# Functional tool checking pipeline
function Test-AllTools {
    param(
        [hashtable[]]$RequiredTools,
        [hashtable[]]$OptionalTools,
        [hashtable[]]$VerificationCommands
    )
    
    # Create verification lookup
    $verificationLookup = $VerificationCommands | ForEach-Object { 
        @{ $_.Tool = $_.Command } 
    } | Merge-Hashtables
    
    $requiredStatus = $RequiredTools | ForEach-Object {
        Get-ToolStatus $_ $verificationLookup[$_.Name]
    }
    
    $optionalStatus = $OptionalTools | ForEach-Object {
        Get-ToolStatus $_ $verificationLookup[$_.Name]
    }
    
    @{
        Required = $requiredStatus
        Optional = $optionalStatus
        AllRequiredReady = ($requiredStatus | Where-Object { $_.Status -ne "READY" }).Count -eq 0
        Summary = @{
            RequiredReady = ($requiredStatus | Where-Object { $_.Status -eq "READY" }).Count
            RequiredMissing = ($requiredStatus | Where-Object { $_.Status -ne "READY" }).Count
            OptionalReady = ($optionalStatus | Where-Object { $_.Status -eq "READY" }).Count
            OptionalMissing = ($optionalStatus | Where-Object { $_.Status -ne "READY" }).Count
        }
    }
}

# Functional tool downloading
function Invoke-ToolDownload {
    param([hashtable]$Tool, [string]$ToolsDirectory)
    
    try {
        switch ($Tool.ExtractionMethod) {
            "direct_download" { 
                Invoke-DirectDownload $Tool.DownloadUrl $Tool.TargetPath 
            }
            "zip_extract" { 
                Invoke-ZipDownloadAndExtract $Tool $ToolsDirectory 
            }
            "msi_download" { 
                Invoke-DirectDownload $Tool.DownloadUrl $Tool.TargetPath 
            }
            "manual_download" { 
                @{ Success = $false; Message = "Manual download required" } 
            }
            default { 
                @{ Success = $false; Message = "Unknown extraction method" } 
            }
        }
    } catch {
        @{ Success = $false; Message = $_.Exception.Message }
    }
}

function Invoke-DirectDownload {
    param([string]$Url, [string]$TargetPath)
    
    $targetDir = Split-Path $TargetPath -Parent
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    
    Invoke-WebRequest $Url -OutFile $TargetPath -UseBasicParsing
    @{ Success = $true; Message = "Downloaded successfully" }
}

function Invoke-ZipDownloadAndExtract {
    param([hashtable]$Tool, [string]$ToolsDirectory)
    
    $tempZip = Join-Path $ToolsDirectory "$($Tool.Name).zip"
    $tempExtract = Join-Path $ToolsDirectory "$($Tool.Name)_temp"
    
    try {
        # Download and extract
        Invoke-WebRequest $Tool.DownloadUrl -OutFile $tempZip -UseBasicParsing
        Expand-Archive $tempZip $tempExtract -Force
        
        # Find and move target file
        $sourcePath = if ($Tool.VerifyFile) {
            $candidatePath = Join-Path $tempExtract $Tool.VerifyFile
            if (Test-Path $candidatePath) {
                $candidatePath
            } else {
                # Search recursively
                Get-ChildItem $tempExtract -Recurse -File | 
                Where-Object { $_.Name -eq (Split-Path $Tool.VerifyFile -Leaf) } |
                Select-Object -First 1 -ExpandProperty FullName
            }
        } else {
            Get-ChildItem $tempExtract -File | Select-Object -First 1 -ExpandProperty FullName
        }
        
        if ($sourcePath -and (Test-Path $sourcePath)) {
            $targetDir = Split-Path $Tool.TargetPath -Parent
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            
            Move-Item $sourcePath $Tool.TargetPath -Force
            @{ Success = $true; Message = "Downloaded and extracted successfully" }
        } else {
            @{ Success = $false; Message = "Could not find target file in archive" }
        }
    } finally {
        # Cleanup
        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Utility functions
function Merge-Hashtables {
    param([Parameter(ValueFromPipeline)]$Hashtable)
    
    begin { $result = @{} }
    process { 
        $Hashtable.GetEnumerator() | ForEach-Object { 
            $result[$_.Key] = $_.Value 
        } 
    }
    end { $result }
}

function Write-ToolStatus {
    param([hashtable]$Status)
    
    $icon = switch ($Status.Status) {
        "READY" { "✓" }
        "PRESENT_NOT_WORKING" { "⚠️" }
        "MISSING" { "❌" }
    }
    
    Write-Host "   $icon $($Status.Name) - $($Status.Status)"
}

function Write-StatusSummary {
    param([hashtable]$TestResults)
    
    Write-Host "🔍 Tool Status Summary:" -ForegroundColor Cyan
    Write-Host "   Required Ready: $($TestResults.Summary.RequiredReady)"
    Write-Host "   Required Missing: $($TestResults.Summary.RequiredMissing)" 
    Write-Host "   Optional Ready: $($TestResults.Summary.OptionalReady)"
    Write-Host "   Optional Missing: $($TestResults.Summary.OptionalMissing)"
    Write-Host "   All Required Ready: $(if($TestResults.AllRequiredReady){'✓ YES'}else{'❌ NO'})"
}

# Main functional pipeline
function Test-ForensicsPrerequisites {
    param(
        [string]$ConfigPath = "E:\tools\tool_config.txt",
        [string]$ToolsDirectory = "E:\tools",
        [switch]$AutoDownload,
        [switch]$GenerateReport
    )
    
    Write-Host "🚀 Functional Forensics Framework Prerequisite Check" -ForegroundColor Cyan
    
    # Ensure tools directory exists
    if (-not (Test-Path $ToolsDirectory)) {
        New-Item -ItemType Directory -Path $ToolsDirectory -Force | Out-Null
    }
    
    # Functional pipeline: Config -> Parse -> Test -> Report
    $config = Get-ToolConfiguration $ConfigPath
    
    $requiredTools = $config | Where-Object { $_.Section -eq "REQUIRED_TOOLS" } | 
                    Select-Object -ExpandProperty Data
    
    $optionalTools = $config | Where-Object { $_.Section -eq "OPTIONAL_TOOLS" } | 
                    Select-Object -ExpandProperty Data
    
    $verificationCommands = $config | Where-Object { $_.Section -eq "TOOL_VERIFICATION" } | 
                           Select-Object -ExpandProperty Data
    
    # Test all tools functionally
    $testResults = Test-AllTools $requiredTools $optionalTools $verificationCommands
    
    # Display results
    Write-Host ""
    Write-Host "Required Tools:" -ForegroundColor Yellow
    $testResults.Required | ForEach-Object { Write-ToolStatus $_ }
    
    Write-Host ""
    Write-Host "Optional Tools:" -ForegroundColor Yellow  
    $testResults.Optional | ForEach-Object { Write-ToolStatus $_ }
    
    Write-Host ""
    Write-StatusSummary $testResults
    
    # Auto-download missing tools if requested
    if ($AutoDownload -and -not $testResults.AllRequiredReady) {
        Write-Host ""
        Write-Host "📥 Auto-downloading missing required tools..." -ForegroundColor Yellow
        
        $missingTools = $testResults.Required | Where-Object { $_.Status -ne "READY" }
        $toolLookup = ($requiredTools + $optionalTools) | ForEach-Object { @{ $_.Name = $_ } } | Merge-Hashtables
        
        $downloadResults = $missingTools | ForEach-Object {
            $tool = $toolLookup[$_.Name]
            if ($tool) {
                Write-Host "   Downloading $($_.Name)..."
                $result = Invoke-ToolDownload $tool $ToolsDirectory
                @{
                    Tool = $_.Name
                    Success = $result.Success
                    Message = $result.Message
                }
            }
        }
        
        # Report download results
        $downloadResults | ForEach-Object {
            $icon = if ($_.Success) { "✓" } else { "❌" }
            Write-Host "   $icon $($_.Tool): $($_.Message)"
        }
        
        # Re-test after downloads
        if (($downloadResults | Where-Object { $_.Success }).Count -gt 0) {
            Write-Host ""
            Write-Host "🔄 Re-checking tools after download..."
            $testResults = Test-AllTools $requiredTools $optionalTools $verificationCommands
            Write-StatusSummary $testResults
        }
    }
    
    # Generate report if requested
    if ($GenerateReport) {
        $reportData = @{
            Timestamp = Get-Date
            ToolsDirectory = $ToolsDirectory
            RequiredTools = $testResults.Required
            OptionalTools = $testResults.Optional
            Summary = $testResults.Summary
            AllReady = $testResults.AllRequiredReady
        }
        
        New-PrerequisiteReport $reportData $ToolsDirectory
    }
    
    @{
        Results = $testResults
        AllReady = $testResults.AllRequiredReady
        GetTool = { param($ToolName) Get-FunctionalTool $ToolName $testResults }.GetNewClosure()
    }
}

function Get-FunctionalTool {
    param([string]$ToolName, [hashtable]$TestResults)
    
    $tool = ($TestResults.Required + $TestResults.Optional) | 
            Where-Object { $_.Name -eq $ToolName -and $_.Status -eq "READY" } |
            Select-Object -First 1
    
    if ($tool) {
        $tool.Path
    } else {
        Write-Warning "Tool $ToolName is not ready"
        $null
    }
}

function New-PrerequisiteReport {
    param([hashtable]$ReportData, [string]$ToolsDirectory)
    
    $reportPath = Join-Path $ToolsDirectory "functional_prerequisite_report.txt"
    
    $report = @"
FUNCTIONAL FORENSICS TOOL PREREQUISITE REPORT
=============================================
Generated: $($ReportData.Timestamp)
Tools Directory: $($ReportData.ToolsDirectory)
Architecture: Functional Programming Style

SUMMARY:
========
Required Tools Ready: $($ReportData.Summary.RequiredReady)
Required Tools Missing: $($ReportData.Summary.RequiredMissing)
Optional Tools Ready: $($ReportData.Summary.OptionalReady)
Optional Tools Missing: $($ReportData.Summary.OptionalMissing)

All Required Tools Ready: $(if($ReportData.AllReady){"✓ YES"}else{"❌ NO"})

REQUIRED TOOLS:
==============
$($ReportData.RequiredTools | ForEach-Object { 
    "$($_.Name) - $($_.Status)`n  Description: $($_.Description)`n  Path: $($_.Path)`n" 
} | Out-String)

OPTIONAL TOOLS:
==============
$($ReportData.OptionalTools | ForEach-Object { 
    "$($_.Name) - $($_.Status)`n  Description: $($_.Description)`n  Path: $($_.Path)`n" 
} | Out-String)

FUNCTIONAL BENEFITS:
===================
✓ Pure functions - no side effects
✓ Composable pipeline architecture  
✓ Immutable data structures
✓ Functional error handling
✓ Declarative configuration processing
✓ Higher-order functions for tool operations
"@
    
    $report | Out-File $reportPath
    Write-Host "📄 Functional prerequisite report saved to: $reportPath"
}