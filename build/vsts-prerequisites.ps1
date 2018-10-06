﻿Write-Host "Installing Pester" -ForegroundColor Cyan
Install-Module Pester -Force -SkipPublisherCheck
Write-Host "Installing PSFramework" -ForegroundColor Cyan
Install-Module PSFramework -Force -SkipPublisherCheck
Write-Host "Installing PSNotification" -ForegroundColor Cyan
Install-Module PSNotification -Force -SkipPublisherCheck
Install-Module PSScriptAnalyzer -Force -SkipPublisherCheck
