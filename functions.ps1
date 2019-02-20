#Requires -Version 6.0

function Get-PuppetDBNode {
    <#
        $getPuppetDBNodeSplat = @{
            master = 'master.contoso.com'
            node   = 'node.contoso.com'
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
            switch -Wildcard ($_.Exception.Message) {
                "*404*" {
                    Write-Warning "(404) Not Found for $node on $master."
                    if ($testExistence -eq $true) {
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
            $result = Invoke-WebRequest -Method Get -Uri $uri -Certificate $certPfx -ContentType 'application/json' -ErrorAction Stop
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
                $result = Invoke-WebRequest -Method Put -Uri $uri -Certificate $certpfx -ContentType 'application/json' -Body $body -ErrorAction Stop
                $content = $result.content | ConvertTo-Json
                Write-Verbose "Sucesfully set cert for $node on $master to $desired_state."
                Write-Output $content
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

function Remove-PuppetDBNode {
    <#
        $removePuppetDBNodeSplat = @{
            master = 'master.contoso.com'
            node   = 'node.contoso.com'
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
        $getPuppetDBNodeResult = Get-PuppetDBNode @getPuppetDBNodeSplat
        if ($getPuppetDBNodeResult) {
            $uri = "https://$master`:$masterPort/pdb/cmd/v1"
            $headers = @{'X-Authentication' = $token}
            $cmdObj = [PSCustomObject]@{
                command = 'deactivate node'
                version = 3
                payload = @{
                    certname           = $node
                    producer_timestamp = (Get-Date -Format o)
                }
            } | ConvertTo-Json
            try {
                $result = Invoke-WebRequest -Uri $uri -Method Post -ContentType 'application/json' -Headers $headers -Body $cmdObj -ErrorAction Stop
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