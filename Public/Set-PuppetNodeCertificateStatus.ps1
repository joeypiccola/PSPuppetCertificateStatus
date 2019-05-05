function Set-PuppetNodeCertificateStatus {
    <#
        $securePwd = ConvertTo-SecureString -AsPlainText -Force -String 'secret'
        $setPuppetNodeCertificateStatusSplat = @{
            master        = 'master.contoso.com'
            node          = 'node.contoso.com'
            certPath      = '/certs/mycert.contoso.com.pfx'
            certPassword  = $securePwd
            desired_state = 'revoked'
        }
        Set-PuppetNodeCertificateStatus @setPuppetNodeCertificateStatusSplat -Verbose
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
        [Parameter(Mandatory)]
        [ValidateSet('signed', 'revoked')]
        [string]$desired_state
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
            if ($getPuppetNodeCertificateStatusResult.state -eq $desired_state) {
                Write-Verbose "Cert for $node on $master already set to $desired_state."
                return
            }
            else {
                $nodeCertState = $getPuppetNodeCertificateStatusResult.state
                switch ($desired_state) {
                    'revoked' {
                        if ($nodeCertState -eq 'requested') {
                            Write-Warning "Cannot revoke cert for $node on $master as it's currently `"$nodeCertState`"."
                            return
                        }
                    }
                    'signed' {
                        if ($nodeCertState -eq 'revoked') {
                            Write-Warning "Cannot sign cert for $node on $master as it's currently `"$nodeCertState`"."
                            return
                        }
                    }
                }
            }
            $uri = "https://$Master`:$masterPort/puppet-ca/v1/certificate_status/$($node.tolower())"
            $body = "{`"desired_state`":`"$desired_state`"}"
            try {
                $certPfx = Get-PfxCertificate -FilePath $certPath -Password $certPassword -ErrorAction Stop
                Write-Verbose "Current state of cert for $node on $master is `"$nodeCertState`"."
                $result = Invoke-RestMethod -Method Put -Uri $uri -Certificate $certpfx -ContentType 'application/json' -Body $body -ErrorAction Stop
                Write-Verbose "Sucesfully set cert for $node on $master to $desired_state."
                Write-Output $result
            }
            catch {
                Write-Error $_
            }
        }
        else {
            Write-Warning "No cert found to set for $node on $master."
        }
    }
    end {
        Write-Verbose "End $($MyInvocation.MyCommand)"
    }
}