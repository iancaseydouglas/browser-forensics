# Functional Digital Forensics Framework

A configuration-driven, functional programming approach to digital forensics investigation with focus on browser cache analysis, deleted data recovery, and cross-platform evidence correlation.

## 🎯 Key Features

- **100% Configuration-Driven** - Zero hardcoded values, all platforms and patterns defined in config files
- **Functional Programming Architecture** - Pure functions, immutable data, composable pipelines
- **Automated Tool Management** - Downloads and verifies forensics tools automatically
- **Byte-Level Image Recovery** - Advanced image signature detection and extraction
- **Cross-Platform Analysis** - Instagram, Facebook, Tumblr, Reddit, Gmail, and more
- **Deleted Data Recovery** - Email contacts, browser cache, hibernation files
- **Timeline Correlation** - Maps digital activity to suspicious time windows

## 🚀 Quick Start

### 1. Download Configuration Files
Save these files to `E:\tools\`:
- `tool_config.txt` - Forensics tool definitions
- `quick_test_config.txt` - Platform and analysis configurations

### 2. Download Core Scripts
Save these PowerShell scripts to `E:\tools\`:
- `functional_tool_manager.ps1` - Core framework
- `functional_quick_test.ps1` - Quick test implementation  
- `main_execution_script.ps1` - Main execution pipeline

### 3. Execute Framework
```powershell
# Run with auto-download and report generation
PowerShell -ExecutionPolicy Bypass -File "E:\tools\main_execution_script.ps1"
```

## 📁 Expected Output Structure

```
E:\QUICK_EVIDENCE\
├── cached_images\           # Extracted profile photos and images
├── functional_test_results.txt
└── recovery_logs\

E:\tools\
├── functional_prerequisite_report.txt
├── sqlite3.exe             # Auto-downloaded tools
├── strings.exe
└── ...other forensics tools
```

## 🔧 Configuration

### Adding New Platforms
Edit `quick_test_config.txt`:
```
# QUICK_TEST_PLATFORMS
NEWPLATFORM|newsite.com,alt-domain.com
```

### Adding New Suspicious Terms
Edit `quick_test_config.txt`:
```
# SUSPICIOUS_DOMAINS
newdatingsite.com,secretapp.com
```

### Adding New Tools
Edit `tool_config.txt`:
```
# REQUIRED_TOOLS
NEWTOOL|download_url|target_path|zip_extract|verify_file|description
```

## 🎯 Investigation Focus Areas

### High-Value Evidence Sources:
1. **Browser Cache Images** - Profile photos, screenshots
2. **Gmail Storage Data** - Deleted contact information
3. **Platform Activity Traces** - Instagram, Facebook, dating sites
4. **Hibernation Files** - Memory dumps with recent activity
5. **Cross-Platform Correlation** - Same usernames across platforms

### Suspicious Timing Analysis:
- Gym times: Wednesday 5-7pm, Saturday 10am-12pm
- Evening phone activity: 6:30-10pm
- Late night/early morning communications
- Activity during "girls dinner" or "selling clothes" outings

## 📊 Expected Results

### Browser History Analysis:
- Total URLs accessible in database
- Platform-specific visit counts
- Suspicious domain activity detection

### Image Recovery:
- JPEG, PNG, GIF, WebP extraction using byte signatures
- Profile photos and cached images
- Metadata preservation for timeline analysis

### Contact Discovery:
- Gmail account information in browser storage
- Email addresses from cached data
- Multiple account detection across platforms

### Platform Correlation:
- Cross-platform username discovery
- Activity timing correlation
- Multiple account pattern detection

## 🛡️ Operational Security

### Evidence Preservation:
- All original files preserved with hash verification
- Chain of custody documentation
- Timestamp preservation for legal admissibility

### System State Restoration:
- File access times restored
- Browser state maintained
- System logs cleaned of investigation traces

### Stealth Operation:
- Works during target's absence (gym times, outings)
- Minimal system impact
- No permanent installation required

## 🔍 Advanced Usage

### Custom Investigation Periods:
```powershell
# Analyze specific time windows
$customResults = Invoke-FunctionalQuickTest -TimeWindow "2024-01-01 to 2024-06-01"
```

### Targeted Platform Analysis:
```powershell
# Focus on specific platforms
$socialResults = Get-PlatformActivity -Platforms @("INSTAGRAM", "FACEBOOK")
```

### Deep Image Recovery:
```powershell
# Extended cache analysis
$imageResults = Get-CachedImages -MaxFiles 5000 -MinSize 1000
```

## 📈 Success Metrics

### High-Confidence Indicators:
- **Multiple accounts** on same platform (Instagram, Facebook)
- **Cross-platform username correlation** (same user across different sites)
- **Suspicious timing patterns** (activity during gym/dinner times)
- **Dating site activity** with cached profile photos
- **Deleted Gmail contacts** recovered from storage

### Evidence Quality Scale:
- **🔴 Critical**: Multiple dating profiles with photos + cross-platform correlation
- **🟡 Moderate**: Single platform suspicious activity + timing correlation  
- **🟢 Suggestive**: Browser traces + cached data without clear correlation

## 🏗️ Architecture Benefits

### Functional Programming Advantages:
- **Testable**: Pure functions with predictable outputs
- **Maintainable**: Composable functions and immutable data
- **Scalable**: Easy to add new platforms and analysis types
- **Reliable**: No side effects or hidden state mutations

### Configuration-Driven Design:
- **Flexible**: Modify behavior without code changes
- **Updatable**: Add new platforms via config file edits
- **Portable**: Same code works across different investigations
- **Maintainable**: Single source of truth for all patterns

## ⚖️ Legal Considerations

- Ensure proper authorization before running on any system
- Maintain chain of custody for all extracted evidence
- Document all investigative steps for potential legal proceedings
- Consider consulting with legal counsel regarding admissibility

## 🆘 Troubleshooting

### Common Issues:
1. **SQLite Access Denied** - Ensure browser is closed during analysis
2. **Tool Download Failures** - Check internet connection and antivirus settings
3. **Cache Access Errors** - Run PowerShell as Administrator
4. **Empty Results** - Verify Edge profile path and recent browser activity

### Debug Mode:
```powershell
# Enable verbose output
$VerbosePreference = "Continue"
$DebugPreference = "Continue"
```

## 🔄 Updates and Maintenance

The framework automatically:
- Downloads required forensics tools
- Verifies tool functionality
- Updates configuration-driven patterns
- Maintains evidence integrity

For updates, simply modify the configuration files - no code changes required.

---

**Remember**: This framework is designed for legitimate digital forensics investigations. Always ensure proper authorization and legal compliance before use.
