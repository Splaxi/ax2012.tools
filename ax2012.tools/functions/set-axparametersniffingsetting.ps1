﻿
<#
    .SYNOPSIS
        Get the parameter sniffing configuration
        
    .DESCRIPTION
        Get the parameter sniffing value from the database that has been released by Microsoft for AX 2012
        
    .PARAMETER DatabaseServer
        Server name of the database server
        
        Default value is: "localhost"
        
    .PARAMETER DatabaseName
        Name of the database
        
        Default value is: "MicrosoftDynamicsAx"
        
    .PARAMETER SqlUser
        User name of the SQL Server credential that you want to use when working against the database
        
    .PARAMETER SqlPwd
        Password of the SQL Server credential that you want to use when working against the database
        
    .PARAMETER GenerateScript
        When provided the SQL is returned and not executed
        
        Note: This is useful for troubleshooting or providing the script to a DBA with access to the server
        
    .EXAMPLE
        PS C:\> Set-AxParameterSniffingSetting
        
        This will configure the correct parameter sniffing settings.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
        
#>
function Set-AxParameterSniffingSetting {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    #[OutputType()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [string] $DatabaseServer = $Script:ActiveAosDatabaseserver,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 2)]
        [string] $DatabaseName = $Script:ActiveAosDatabase,

        [Parameter(Mandatory = $false, Position = 3)]
        [string] $SqlUser,

        [Parameter(Mandatory = $false, Position = 4)]
        [string] $SqlPwd,

        [Switch] $GenerateScript
    )

    Invoke-TimeSignal -Start

    $baseParams = Get-DeepClone $PSBoundParameters
    $baseParams.Add("TrustedConnection", $true)

    $UseTrustedConnection = Test-TrustedConnection $baseParams

    $SqlParams = @{ DatabaseServer = $DatabaseServer; DatabaseName = $DatabaseName;
        SqlUser = $SqlUser; SqlPwd = $SqlPwd
    }

    $sqlCommand = Get-SqlCommand @SqlParams -TrustedConnection $UseTrustedConnection

    $sqlCommand.CommandText = (Get-Content "$script:ModuleRoot\internal\sql\set-axparametersniffingsetting.sql") -join [Environment]::NewLine

    if ($GenerateScript) {
        (Get-SqlString $sqlCommand)
    }
    else {
        try {
            Write-PSFMessage -Level InternalComment -Message "Executing a script against the database." -Target (Get-SqlString $sqlCommand)

            $sqlCommand.Connection.Open()
            $sqlCommand.ExecuteNonQuery()

            Write-PSFMessage -Level Verbose -Message "SQL query executed."
        }
        catch {
            Write-PSFMessage -Level Host -Message "Something went wrong while working against the database" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
        finally {
            if ($sqlCommand.Connection.State -ne [System.Data.ConnectionState]::Closed) {
                $sqlCommand.Connection.Close()
            }
    
            $sqlCommand.Dispose()
        }
    }

    Invoke-TimeSignal -End
}