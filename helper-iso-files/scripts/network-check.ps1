Add-Type -AssemblyName PresentationFramework

function wait-for-network ($tries) {
    while (1) {
        # Get a list of DHCP-enabled interfaces that have a 
        # non-$null DefaultIPGateway property.
        $x = gwmi -class Win32_NetworkAdapterConfiguration `
            -filter DHCPEnabled=TRUE |
                where { $_.DefaultIPGateway -ne $null }

        # If there is (at least) one available, exit the loop.
        if ( ($x | measure).count -gt 0 ) {
            #[System.Windows.MessageBox]::Show("Network connection established!", "MobilePassThrough")
            Write-Host "Network connection established!"
            break
        }

        # If $tries > 0 and we have tried $tries times without
        # success, throw an exception.
        if ( $tries -gt 0 -and $try++ -ge $tries ) {
            Write-Host "Network unavaiable after $try tries."
            [System.Windows.MessageBox]::Show("Network unavaiable after $try tries.", "MobilePassThrough")
            throw "Network unavaiable after $try tries."
        }

        # Wait one second.
        start-sleep -s 1
    }
}

function wait-for-chocolatey ($tries) {
    while (1) {
        if ( $tries -gt 0 -and $try++ -ge $tries ) {
            Write-Host "chocolatey.org unavaiable after $try tries."
            [System.Windows.MessageBox]::Show("chocolatey.org unavaiable after $try tries.", "MobilePassThrough")
            throw "chocolatey.org unavaiable after $try tries."
        }
        if ((Test-Connection -Quiet chocolatey.org)) {
            Write-Host "chocolatey.org is reachable!"
            break
        }
        start-sleep -s 1
    }
}

Write-Host "Waiting for a network connection. Waiting up to 60 seconds..."
wait-for-network 60

Write-Host "Setting the Network to private..."
Set-NetConnectionProfile -Name "Network" -NetworkCategory Private

Write-Host "Waiting for chocoltey.org to be reachable. Waiting up to 30 seconds..."
wait-for-chocolatey 30

cmd /q /c "FOR %i IN (A B C D E F G H I J K L N M O P Q R S T U V W X Y Z) DO IF EXIST %i:\scripts\chcolatey-install.ps1  cmd /c powershell -executionpolicy unrestricted -file %i:\scripts\chcolatey-install.ps1"