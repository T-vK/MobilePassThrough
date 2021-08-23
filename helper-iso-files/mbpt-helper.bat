cd /D %~dp0

echo "Set poweshell execution policy to unrestricted..."
powershell -Command "Set-ExecutionPolicy Unrestricted

echo "Disable password expiration for Administrator user..."
wmic useraccount where "name='Administrator'" set PasswordExpires=FALSE

echo "Installing required Visual C++ Redistributable Package..."
.\bin\VC_redist.x64.exe /install /passive /norestart

echo "Install vfio drivers..."
certutil -addstore "TrustedPublisher" .\RedHat.cer
%WINDIR%\system32\pnputil.exe /add-driver .\bin\virtio-drivers\Win10\amd64\*.inf /subdirs /install

echo "Disable mouse acceleration..."
powershell -executionpolicy unrestricted -file .\scripts\disable-mouse-acceleration.ps1

echo "Install Spice guest tools..."
.\bin\spice-guest-tools.exe /S

echo "Install Spice WebDAV daemon..."
.\bin\spice-webdavd.msi /passive /norestart

echo "Install Looking Glass to Program Files ..."
.\bin\looking-glass-host-setup.exe /S

echo "Changing the virtual Ethernet adapter to a private one to allow RDP access..."
for /F "skip=3 tokens=1,2,3* delims= " %%G in ('netsh interface show interface') DO (
    echo "Setting %%J to private..."
    powershell -command Set-NetConnectionProfile -InterfaceAlias "Network" -NetworkCategory Private
)

echo "Enable remote desktop..."
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes

echo "Copy gpu-check script to startup..."
md "%APPDATA%\mbpt"
copy .\scripts\gpu-check.ps1 "%APPDATA%\mbpt"
copy .\scripts\mbpt-startup.bat "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

echo "Wait until we're connected to the Internet..."
powershell -executionpolicy unrestricted -file .\scripts\network-check.ps1

echo "Install Chocolatey if possible..."
powershell -executionpolicy unrestricted -file .\scripts\chocolatey-install.ps1

echo "Run GPU check..."
powershell -executionpolicy unrestricted -file .\scripts\gpu-check.ps1 unattended

echo "Done! Shutting down the VM in 30 seconds..."

shutdown -s

pause

::echo "Set static IP for vfio network device..."
:: TODO: Find the correct network adapter name
::netsh int ip set address "Ethernet" static 192.168.99.2 255.255.255.0 192.168.99.1 1
::netsh int ip set dns "Ethernet" static 192.168.99.1 primary
:: netsh int ip set address "Local Area Connection" static 192.168.99.2 255.255.255.0 192.168.99.1 1
:: netsh int ip set dns "Local Area Connection" static 192.168.99.1 primary

::echo "Waiting for 5 seconds..."
::timeout /t 5 /nobreak > nul