Add-Type -AssemblyName PresentationFramework

#try {
#    choco
#}
#catch {
#    Remove-Item C:\ProgramData\chocolatey -Recurse
#    [System.Windows.MessageBox]::Show('Chocolatey installation failed! Make sure the VM has Internet access.', "MobilePassThrough - Error")
#}

#For formatting:
     $result = @{Expression = {$_.Name}; Label = "Device Name"},
               @{Expression = {$_.ConfigManagerErrorCode} ; Label = "Status Code" },
               @{Expression = {$_.DeviceID} ; Label = "ID" }

$driverlessGpus = Get-WmiObject -Class Win32_PnpEntity -ComputerName localhost -Namespace Root\CIMV2 | Where-Object {$_.ConfigManagerErrorCode -gt 0 } | Format-Table $result -AutoSize | findstr -i "Video Controller" | findstr -i " 28 "

if ($driverlessGpus -like '*VEN_1002*') {
    Write-Host 'AMD GPU driver missing'
    Write-Host 'Automatically installing AMD GPU drivers is not supported.'
    [System.Windows.MessageBox]::Show("Please install the AMD GPU driver! AMD and Chocolatey unfortunately don't offer a way to do this automatically!", "MobilePassThrough - GPU Driver is missing")
}
if ($driverlessGpus -like '*VEN_10DE*') {
    Write-Host 'Nvidia GPU driver missing'
    try {
        #choco install nvidia-display-driver
        Write-Host 'Automatic GPU driver installation not implemented yet. Please install the Nvidia Display driver manually!'
        [System.Windows.MessageBox]::Show('Automatic GPU driver installation not implemented yet. Please install the Nvidia Display driver manually!', "MobilePassThrough - Missing GPU driver")
    }
    catch {
        [System.Windows.MessageBox]::Show('Failed to automatically install Nvidia Display driver using chocolatey!', "MobilePassThrough - driver installation failed")
    }
}
if ($driverlessGpus -like '*VEN_8086*') {
    Write-Host 'Intel GPU driver missing'
    try {
        #choco install intel-graphics-driver
        Write-Host 'Automatic GPU driver installation not implemented yet. Please install the Intel Graphics driver manually!'
        [System.Windows.MessageBox]::Show('Automatic GPU driver installation not implemented yet. Please install the Intel Graphics driver manually!', "MobilePassThrough - Missing GPU driver")
 
    }
    catch {
        [System.Windows.MessageBox]::Show('Failed to automatically install Intel Graphics driver using chocolatey!', "MobilePassThrough - driver installation failed")
    }
}

$error43Devices = Get-WmiObject -Class Win32_PnpEntity -ComputerName localhost -Namespace Root\CIMV2 | Where-Object {$_.ConfigManagerErrorCode -gt 0 } | Format-Table $result -AutoSize | findstr -i "Video Controller" | findstr -i " 43 "

if ($error43Devices) {
    Write-Host 'Error 43 detected:'
    Write-Host $error43Devices
    [System.Windows.MessageBox]::Show($error43Devices, "MobilePassThrough - Detected Error 43")
}
