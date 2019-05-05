function Get-PuppetNodeCertificateStatus {
    <#
        $securePwd = ConvertTo-SecureString -AsPlainText -Force -String 'secret'
        $getPuppetNodeCertificateStatusSplat = @{
            master       = 'master.contoso.com'
            node         = 'node.contoso.com'
            certPath     = '/certs/mycert.contoso.com.pfx'
            certPassword = $securePwd
        }
        Get-PuppetNodeCertificateStatus @getPuppetNodeCertificateStatusSplat -Verbose
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$master,
        [Parameter()]
        [int]$masterPort = 8140,
        [Parameter(Mandatory)]
        [string]$node,
        [Parameter(Mandatory)]
        [string]$certPath,
        [Parameter(Mandatory)]
        [Security.SecureString]$certPassword,
        [Parameter()]
        [switch]$testExistence
    )
    begin {
        Write-Verbose "Begin $($MyInvocation.MyCommand)"
    }
    process {
        $uri = "https://$Master`:$masterPort/puppet-ca/v1/certificate_status/$($node.tolower())"
        try {
            $certPfx = Get-PfxCertificate -FilePath $certPath -Password $certPassword -ErrorAction Stop
            $result = Invoke-RestMethod -Method Get -Uri $uri -Certificate $certPfx -ContentType 'application/json' -ErrorAction Stop
            if ($testExistence) {
                Write-Output $true
            }
            else {
                Write-Output $result
            }
        }
        catch {
            switch ($_) {
                'Resource not found.' {
                    Write-Warning "Resource not found for $node on $master"
                    if ($testExistence) {
                        Write-Output $false
                    }
                }
                Default {
                    Write-Error $_
                }
            }
        }
    }
    end {
        Write-Verbose "End $($MyInvocation.MyCommand)"
    }
}