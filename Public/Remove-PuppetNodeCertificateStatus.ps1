function Remove-PuppetNodeCertificate {
    <#
        $securePwd = ConvertTo-SecureString -AsPlainText -Force -String 'secret'
        $removePuppetNodeCertificateSplat = @{
            master       = 'master.contoso.com'
            node         = 'node.contoso.com'
            certPath     = '/certs/mycert.contoso.com.pfx'
            certPassword = $securePwd
        }
        Remove-PuppetNodeCertificate @removePuppetNodeCertificateSplat -Verbose
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
        [switch]$force
    )
    begin {
        Write-Verbose "Begin $($MyInvocation.MyCommand)"
    }
    process {
        $getPuppetNodeCertificateStatusSplat = @{
            master       = $master
            node         = $node
            certPath     = $certpath
            certPassword = $certPassword
        }
        $getPuppetNodeCertificateStatusResult = Get-PuppetNodeCertificateStatus @getPuppetNodeCertificateStatusSplat
        if ($getPuppetNodeCertificateStatusResult) {
            $nodeCertState = $getPuppetNodeCertificateStatusResult.state
            if (($nodeCertState -match 'requested|signed' -and $force) -or ($nodeCertState -eq 'revoked')) {
                $uri = "https://$Master`:$masterPort/puppet-ca/v1/certificate_status/$($node.tolower())"
                try {
                    $certPfx = Get-PfxCertificate -FilePath $certPath -Password $certPassword -ErrorAction Stop
                    Write-Verbose "Current state of cert for $node on $master is `"$nodeCertState`"."
                    $result = Invoke-RestMethod -Method Delete -Uri $uri -Certificate $certpfx -Headers @{"Content-Type" = "application/json"} -ErrorAction Stop
                    Write-Verbose "Sucesfully deleted cert for $node on $master."
                    Write-Output $result
                }
                catch {
                    Write-Error $_
                }
            }
            else {
                Write-Warning "Cert for $node on $master is currently $($getPuppetNodeCertificateStatusResult.state). If signed, revoke it first or use -Force. If requested, use -Force."
            }
        }
        else {
            Write-Warning "No cert found to remove for $node on $master."
        }
    }
    end {
        Write-Verbose "End $($MyInvocation.MyCommand)"
    }
}