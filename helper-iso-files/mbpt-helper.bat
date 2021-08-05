cd /D %~dp0

echo "Installing required Visual C++ Redistributable Package..."
.\bin\VC_redist.x64.exe /install /passive /norestart

echo "Install Looking Glass to Program Files ..."
:: mkdir "%ProgramFiles%\LookingGlass"
:: xcopy /s ".\bin\looking-glass-host.exe" "%ProgramFiles%\LookingGlass\looking-glass-host.exe"
.\bin\looking-glass-host-setup.exe /S

echo "MobilePassThrough Helper, Register Looking Glass as a startup application..."
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "LookingGlass" /t REG_SZ /f /d "%ProgramFiles%\Looking Glass (host)\looking-glass-host.exe -f"

echo "Install vfio drivers..."
certutil -addstore "TrustedPublisher" .\RedHat.cer
%WINDIR%\system32\pnputil.exe /add-driver .\bin\virtio-drivers\Win10\amd64\*.inf /subdirs /install

::echo "Set static IP for vfio network device..."
:: TODO: Find the correct network adapter name
::netsh int ip set address "Ethernet" static 192.168.99.2 255.255.255.0 192.168.99.1 1
::netsh int ip set dns "Ethernet" static 192.168.99.1 primary
:: netsh int ip set address "Local Area Connection" static 192.168.99.2 255.255.255.0 192.168.99.1 1
:: netsh int ip set dns "Local Area Connection" static 192.168.99.1 primary

::echo "Waiting for 5 seconds..."
::timeout /t 5 /nobreak > nul

echo "Change the virtual Ethernet adapter to a private one to allow RDP access..."
powershell -command Set-NetConnectionProfile -Name "Network" -NetworkCategory Private 

echo "Enable remote desktop..."
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes