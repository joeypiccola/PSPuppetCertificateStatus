# PSPuppetCertificateStatus

A set of PowerShell functions to manage Puppet node certificates. The goal behind these functions is to help deprovision Puppet nodes.

- `Get-PuppetNodeCertificateStatus`
- `Set-PuppetNodeCertificateStatus`
- `Remove-PuppetNodeCertificate`
- `Get-PuppetDBNode`
- `Remove-PuppetDBNode`

## Requirements

PowerShell Core

## Examples

### Get-PuppetNodeCertificateStatus

Get the certificate status for a node. Use `-testExistnace` to simply return a `bool` for whether or not a certificate exists.

```powershell
$securePwd = ConvertTo-SecureString -AsPlainText -Force -String 'secret'
$getPuppetNodeCertificateStatusSplat = @{
    master       = 'master.contoso.com'
    node         = 'node.contoso.com'
    certPath     = '/certs/mycert.contoso.com.pfx'
    certPassword = $securePwd
}
Get-PuppetNodeCertificateStatus @getPuppetNodeCertificateStatusSplat -Verbose
```

### Set-PuppetNodeCertificateStatus

Set the certificate status for a node. Valid options for `desired_state` are `signed` or `revoked`.

```powershell
$securePwd = ConvertTo-SecureString -AsPlainText -Force -String 'secret'
$setPuppetNodeCertificateStatusSplat = @{
    master        = 'master.contoso.com'
    node          = 'node.contoso.com'
    certPath      = '/certs/mycert.contoso.com.pfx'
    certPassword  = $securePwd
    desired_state = 'revoked'
}
Set-PuppetNodeCertificateStatus @setPuppetNodeCertificateStatusSplat -Verbose
```

### Remove-PuppetNodeCertificate

Delete the certificate for a node. Use `-Force` when deleting a certficiate with a status of either `requested` or `signed`.

```powershell
$securePwd = ConvertTo-SecureString -AsPlainText -Force -String 'secret'
$removePuppetNodeCertificateSplat = @{
    master       = 'master.contoso.com'
    node         = 'node.contoso.com'
    certPath     = '/certs/mycert.contoso.com.pfx'
    certPassword = $securePwd
}
Remove-PuppetNodeCertificate @removePuppetNodeCertificateSplat -Verbose
```

### Get-PuppetDBNode

Query the PuppetDB for a node. Use `-testExistnace` to simply return a `bool` for whether or not a node exists.

```powershell
$getPuppetDBNodeSplat = @{
    master = 'master.contoso.com'
    node   = 'node.contoso.com'
    token  = $token
}
Get-PuppetDBNode @getPuppetDBNodeSplat -Verbose
```

### Remove-PuppetDBNode

Delete a node from the PuppetDB.

```powershell
$removePuppetDBNodeSplat = @{
    master = 'master.contoso.com'
    node   = 'node.contoso.com'
    token  = $token
}
Remove-PuppetDBNode @removePuppetDBNodeSplat -Verbose
```