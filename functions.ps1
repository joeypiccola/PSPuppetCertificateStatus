function Get-PuppetDBNode {
    <#
        $getPuppetDBNodeSplat = @{
            master = 'puppet.piccola.us'
            node   = 'las1-node-1.ad.piccola.us'
            token  = $token
        }
        Get-PuppetDBNode @getPuppetDBNodeSplat -Verbose
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$token,
        [Parameter(Mandatory)]
        [string]$master,
        [Parameter(Mandatory)]
        [string]$node,
        [Parameter()]
        [int]$masterPort = 8081,
        [Parameter()]
        [switch]$testExistence
    )
    begin {
        Write-Verbose "Begin $($MyInvocation.MyCommand)"
    }
    process {
        $uri = "https://$master`:$masterPort/pdb/query/v4/nodes/$node"
        $headers = @{'X-Authentication' = $token}
        try {
            $result = Invoke-WebRequest -Uri $uri -Method Get -Headers $headers -ErrorAction Stop
            $content = $result.content | ConvertFrom-Json
            if ($testExistence) {
                Write-Output $true
            }
            else {
                Write-Output $content
            }
        }
        catch {
            switch ($_.Exception.Message) {
                'The remote server returned an error: (404) Not Found.' {
                    Write-Warning "(404) Not Found for $node on $master."
                    if ($testExistence -eq $true) {
                        Write-Output $false
                    }
                }
                Default {
                    Write-Error $_.Exception.Message
                }
            }
        }
    }
    end {
        Write-Verbose "End $($MyInvocation.MyCommand)"
    }
}

function Get-PuppetNodeCertificateStatus {
    <#
        $getPuppetNodeCertificateStatusSplat = @{
            master   = 'puppet.piccola.us'
            node     = 'las1-node-1.ad.piccola.us'
            certPath = 'C:\Users\joey.piccola\Desktop\joey.piccola.us.pfx'
        }
        Get-PuppetNodeCertificateStatus @getPuppetNodeCertificateStatusSplat
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
        [Parameter()]
        [string]$certPwd,
        [Parameter()]
        [switch]$testExistence
    )
    begin {
        Write-Verbose "Begin $($MyInvocation.MyCommand)"
    }
    process {
        if ($certPwd) {
            $certpfx = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
            $certpfx.Import($certPath, $certPwd, 'DefaultKeySet')
        }
        else {
            $certpfx = Get-PfxCertificate -FilePath $certPath
        }
        $uri = "https://$Master`:$masterPort/puppet-ca/v1/certificate_status/$($node.tolower())"
        try {
            $result = Invoke-WebRequest -Method Get -Uri $uri -Certificate $certpfx -Headers @{"Content-Type" = "application/json"} -ErrorAction Stop
            $content = $result.content | ConvertFrom-Json
            if ($testExistence) {
                Write-Output $true
            }
            else {
                Write-Output $content
            }
        }
        catch {
            switch ($_) {
                'Resource not found.' {
                    Write-Verbose "Resource not found for $node on $master"
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

function Set-PuppetNodeCertificateStatus {
    <#
        $setPuppetNodeCertificateStatusSplat = @{
            master        = 'puppet.piccola.us'
            node          = 'las1-node-1.ad.piccola.us'
            certPath      = 'C:\Users\joey.piccola\Desktop\joey.piccola.us.pfx'
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
        [Parameter()]
        [string]$certPwd,
        [Parameter(Mandatory)]
        [ValidateSet('signed', 'revoked')]
        [string]$desired_state
    )
    begin {
        Write-Verbose "Begin $($MyInvocation.MyCommand)"
    }
    process {
        $PuppetNodeCertificateStatusSplat = @{
            master   = $master
            node     = $node
            certpath = $certpath
            certPwd  = $certPwd
        }
        $PuppetNodeCertificateStatusResult = Get-PuppetNodeCertificateStatus @PuppetNodeCertificateStatusSplat
        if ($PuppetNodeCertificateStatusResult) {
            if ($PuppetNodeCertificateStatusResult.state -eq $desired_state) {
                Write-Verbose "Cert for $node on $master already set to $desired_state."
                return
            }
            else {
                $nodeCertState = $PuppetNodeCertificateStatusResult.state
                switch ($desired_state) {
                    'revoked' {
                        if ($nodeCertState -eq 'requested') {
                            Write-Verbose "Cannot revoke cert for $node on $master as it's currently `"$nodeCertState`"."
                            return
                        }
                    }
                    'signed' {
                        if ($nodeCertState -eq 'revoked') {
                            Write-Verbose "Cannot sign cert for $node on $master as it's currently `"$nodeCertState`"."
                            return
                        }
                    }
                }
            }
            if ($certPwd) {
                $certpfx = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
                $certpfx.Import($certPath, $certPwd, 'DefaultKeySet')
            }
            else {
                $certpfx = Get-PfxCertificate -FilePath $certPath
            }
            $uri = "https://$Master`:$masterPort/puppet-ca/v1/certificate_status/$($node.tolower())"
            $body = "{`"desired_state`":`"$desired_state`"}"
            try {
                Write-Verbose "Current state of cert for $node on $master is `"$nodeCertState`"."
                $result = Invoke-WebRequest -Method Put -Uri $uri -Certificate $certpfx -Headers @{"Content-Type" = "application/json"} -Body $body -ErrorAction Stop
                $json = $result.content | ConvertTo-Json
                Write-Verbose "Sucesfully set cert for $node on $master to $desired_state."
                Write-Output $json
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

function Remove-PuppetNodeCertificate {
    <#
        $removePuppetNodeCertificateSplat = @{
            master   = 'puppet.piccola.us'
            node     = 'las1-node-1.ad.piccola.us'
            certPath = 'C:\Users\joey.piccola\Desktop\joey.piccola.us.pfx'
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
        [Parameter()]
        [string]$certPwd,
        [Parameter()]
        [switch]$force
    )
    begin {
        Write-Verbose "Begin $($MyInvocation.MyCommand)"
    }
    process {
        $getPuppetNodeCertificateStatusSplat = @{
            master   = $master
            node     = $node
            certpath = $certpath
            certPwd  = $certPwd
        }
        $PuppetNodeCertificateStatusResult = Get-PuppetNodeCertificateStatus @getPuppetNodeCertificateStatusSplat
        if ($PuppetNodeCertificateStatusResult) {
            $nodeCertState = $PuppetNodeCertificateStatusResult.state
            if (($nodeCertState -match 'requested|signed' -and $force) -or ($nodeCertState -eq 'revoked')) {
                if ($certPwd) {
                    $certpfx = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
                    $certpfx.Import($certPath, $certPwd, 'DefaultKeySet')
                }
                else {
                    $certpfx = Get-PfxCertificate -FilePath $certPath
                }
                $uri = "https://$Master`:$masterPort/puppet-ca/v1/certificate_status/$($node.tolower())"
                try {
                    Write-Verbose "Current state of cert for $node on $master is `"$nodeCertState`"."
                    $result = Invoke-WebRequest -Method Delete -Uri $uri -Certificate $certpfx -Headers @{"Content-Type" = "application/json"} -ErrorAction Stop
                    $content = $result.content | ConvertFrom-Json
                    Write-Verbose "Sucesfully deleted cert for $node on $master."
                    Write-Output $content
                }
                catch {
                    Write-Error $_
                }
            }
            else {
                Write-Warning "Cert for $node on $master is currently $($PuppetNodeCertificateStatusResult.state). If signed, revoke it first or use -Force. If requested, sign and revoke it first or use -Force."
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

function Remove-PuppetDBNode {
    <#
        $removePuppetDBNodeSplat = @{
            master = 'puppet.piccola.us'
            node   = 'las1-node-1.ad.piccola.us'
            token  = $token
        }
        Remove-PuppetDBNode @removePuppetDBNodeSplat -Verbose
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$token,
        [Parameter(Mandatory)]
        [string]$master,
        [Parameter(Mandatory)]
        [string]$node,
        [Parameter()]
        [int]$masterPort = 8081,
        [Parameter()]
        [switch]$testExistence
    )
    begin {
        Write-Verbose "Begin $($MyInvocation.MyCommand)"
    }
    process {
        $getPuppetDBNodeSplat = @{
            master = $master
            node   = $node
            token  = $token
        }
        if (Get-PuppetDBNode @getPuppetDBNodeSplat) {
            $uri = "https://$master`:$masterPort/pdb/cmd/v1"
            $headers = @{
                'X-Authentication' = $token
                'Content-Type'     = "application/json"
            }
            $cmdObj = [PSCustomObject]@{
                command = 'deactivate node'
                version = 3
                payload = @{
                    certname           = $node
                    producer_timestamp = (Get-Date -Format o)
                }
            } | ConvertTo-Json
            try {
                $result = Invoke-WebRequest -Uri $uri -Method Post -Headers $headers -Body $cmdObj -ErrorAction Stop
                $content = $result.content | ConvertFrom-Json
                Write-Output $content
            }
            catch {
                Write-Error $_
            }
        }
        else {
            Write-Warning "No node found in Puppet DB for $node on $master."
        }
    }
    end {
        Write-Verbose "End $($MyInvocation.MyCommand)"
    }
}