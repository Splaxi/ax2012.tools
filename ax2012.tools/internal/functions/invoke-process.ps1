﻿
<#
    .SYNOPSIS
        Invoke a process
        
    .DESCRIPTION
        Invoke a process and pass the needed parameters to it
        
    .PARAMETER Path
        Path to the program / executable that you want to start
        
    .PARAMETER Params
        Array of string parameters that you want to pass to the executable
        
    .PARAMETER TimeoutInMinutes
        Number of minutes the process is allowed to run, before you want it to exit
        
    .PARAMETER ShowOriginalProgress
        Instruct the cmdlet to show the standard output in the console
        
        Default is $false which will silence the standard output
        
    .PARAMETER OutputCommandOnly
        Instruct the cmdlet to only output the command that you would have to execute by hand
        
        Will include full path to the executable and the needed parameters based on your selection
        
    .PARAMETER EnableException
        This parameters disables user-friendly warnings and enables the throwing of exceptions
        This is less user friendly, but allows catching exceptions in calling scripts
        
    .EXAMPLE
        PS C:\> Invoke-Process -Path "C:\Program Files\Microsoft Dynamics AX\60\Server\AXTEST\Bin\AXBuild.exe" -Params "xppcompileall","/altbin=`"C:\Program Files (x86)\Microsoft Dynamics AX\60\Client\Bin`"","/aos=01","/dbserver=`"SQLTEST`"","/modelstore=`"AXTEST_model`"","/log=`"c:\temp\ax2012.tools\AxBuildLog`"","/compiler=`"C:\Program Files\Microsoft Dynamics AX\60\Server\AXTEST\Bin\ax32serv.exe`""
        
        This will invoke the "C:\Program Files\Microsoft Dynamics AX\60\Server\AXTEST\Bin\AXBuild.exe" executable.
        All parameters will be passed to it.
        The standard output will be redirected to a local variable.
        The error output will be redirected to a local variable.
        The standard output will be written to the verbose stream before exiting.
        
        If an error should occur, both the standard output and error output will be written to the console / host.
        
    .EXAMPLE
        PS C:\> Invoke-Process -OutputCommandOnly -Path "C:\Program Files\Microsoft Dynamics AX\60\Server\AXTEST\Bin\AXBuild.exe" -Params "xppcompileall","/altbin=`"C:\Program Files (x86)\Microsoft Dynamics AX\60\Client\Bin`"","/aos=01","/dbserver=`"SQLTEST`"","/modelstore=`"AXTEST_model`"","/log=`"c:\temp\ax2012.tools\AxBuildLog`"","/compiler=`"C:\Program Files\Microsoft Dynamics AX\60\Server\AXTEST\Bin\ax32serv.exe`""
        
        This will generate the command for the "C:\Program Files\Microsoft Dynamics AX\60\Server\AXTEST\Bin\AXBuild.exe" executable.
        All parameters will be included in the output command.
        
    .EXAMPLE
        PS C:\> Invoke-Process -ShowOriginalProgress -Path "C:\Program Files\Microsoft Dynamics AX\60\Server\AXTEST\Bin\AXBuild.exe" -Params "xppcompileall","/altbin=`"C:\Program Files (x86)\Microsoft Dynamics AX\60\Client\Bin`"","/aos=01","/dbserver=`"SQLTEST`"","/modelstore=`"AXTEST_model`"","/log=`"c:\temp\ax2012.tools\AxBuildLog`"","/compiler=`"C:\Program Files\Microsoft Dynamics AX\60\Server\AXTEST\Bin\ax32serv.exe`""
        
        This will invoke the "C:\Program Files\Microsoft Dynamics AX\60\Server\AXTEST\Bin\AXBuild.exe" executable.
        All parameters will be passed to it.
        The standard output will be outputted directly to the console / host.
        The error output will be outputted directly to the console / host.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>

function Invoke-Process {
    [CmdletBinding()]
    [OutputType([System.String], ParameterSetName = "Generate")]
    param (
        [Parameter(Mandatory = $true)]
        
        [Alias('Executable')]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string[]] $Params,

        [int32] $TimeoutInMinutes = 0,

        [switch] $ShowOriginalProgress,

        [Parameter(ParameterSetName = "Generate")]
        [switch] $OutputCommandOnly,

        [switch] $EnableException
    )

    Invoke-TimeSignal -Start

    if (-not (Test-PathExists -Path $Path -Type Leaf)) { return }

    if (Test-PSFFunctionInterrupt) { return }

    [Int32] $millisecondFactor = 60000

    [Int32] $timeoutForExit = 0

    if ($TimeoutInMinutes -eq 0) {
        $timeoutForExit = [Int32]::MaxValue
    }
    else {
        $timeoutForExit = $TimeoutInMinutes * $millisecondFactor
    }

    $tool = Split-Path -Path $Path -Leaf

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "$Path"
    $pinfo.WorkingDirectory = Split-Path -Path $Path -Parent

    if (-not $ShowOriginalProgress) {
        Write-PSFMessage -Level Verbose "Output and Error streams will be redirected (silence mode)"

        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true
    }

    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = "$($Params -join " ")"
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo

    Write-PSFMessage -Level Verbose "Starting the $tool" -Target "$($params -join " ")"

    if ($OutputCommandOnly) {
        Write-PSFMessage -Level Host "$Path $($pinfo.Arguments)"
        return
    }
    
    $p.Start() | Out-Null
    
    if (-not $ShowOriginalProgress) {
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
    }

    Write-PSFMessage -Level Verbose "Waiting for the $tool to complete"

    if(-not ($p.WaitForExit($timeoutForExit))) {
        Write-PSFMessage -Level Host "Timeout for exit has been <c='em'>reached</c>. Will execute a kill operation now."
        
        $p.Kill()

        Write-PSFMessage -Level Host "Standard output was: \r\n $stdout"
        Write-PSFMessage -Level Host "Error output was: \r\n $stderr"

        $messageString = "Stopping because Timeout has been reached."
        Stop-PSFFunction -Message "Stopping because of Timeout." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        return
    }
    
    if ($p.ExitCode -ne 0 -and (-not $ShowOriginalProgress)) {
        Write-PSFMessage -Level Host "Exit code from $tool indicated an error happened. Will output both standard stream and error stream."
        Write-PSFMessage -Level Host "Standard output was: \r\n $stdout"
        Write-PSFMessage -Level Host "Error output was: \r\n $stderr"

        $messageString = "Stopping because an Exit Code from $tool wasn't 0 (zero) like expected."
        Stop-PSFFunction -Message "Stopping because of Exit Code." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        return
    }
    else {
        Write-PSFMessage -Level Verbose "Standard output was: \r\n $stdout"
    }

    Invoke-TimeSignal -End
}