# Pure functional execution with beautiful composition
# Load the functional framework
. "E:\tools\functional_tool_manager.ps1"
. "E:\tools\functional_quick_test.ps1"

# Functional composition pipeline
$result = Start-FunctionalForensicsFramework -AutoDownload -GenerateReports

# Pure functional result handling
$result | ForEach-Object {
    switch ($_.Success) {
        $true { 
            Write-Host "🎊 Functional forensics pipeline completed successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "Key Findings:" -ForegroundColor Cyan
            Write-Host "• Browser URLs: $($_.TestResults.BrowserHistory.TotalUrls)"
            Write-Host "• Cached Images: $($_.TestResults.CachedImages.Count)"
            Write-Host "• Platform Activities: $($_.TestResults.PlatformActivity.Count)"
            Write-Host "• Email Contacts: $(($_.TestResults.EmailContacts | Measure-Object -Property EmailCount -Sum).Sum)"
            Write-Host ""
            Write-Host "📂 Check detailed results in: E:\QUICK_EVIDENCE" -ForegroundColor Yellow
            Write-Host "📄 Reports generated in: E:\tools" -ForegroundColor Yellow
        }
        $false { 
            Write-Host "⚠️ Pipeline execution incomplete due to missing prerequisites" -ForegroundColor Yellow
            Write-Host "Required tools missing: $($_.PrerequisiteResults.Summary.RequiredMissing)"
            Write-Host ""
            Write-Host "💡 Install missing tools manually or check tool_config.txt" -ForegroundColor Cyan
        }
    }
}