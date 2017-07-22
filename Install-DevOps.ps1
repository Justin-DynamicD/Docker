#Requires -RunAsAdministrator
Write-Output "Checking for Hyper-V..."
Try {
    get-vmswitch -ErrorAction STOP -WarningAction STOP
}
Catch {
    Write-Error "Hyper-V is not installed.  Please correct this before continuing as it will reboot your computer."
}

#Update ExecutionPolicy, if Needed
If ((Get-ExecutionPolicy) -eq "restricted") {
    try {
        Set-ExecutionPolicy "RemoteSigned" -Force
    }
    Catch {
        Write-Error "execution policy is going to cause pains, yet I can't seem to update it.  Please correct."
    }
}

If (!((Get-ChildItem Env:Path).Value -match "choco")) {
    Write-Output "Installing Chocolatey..."
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    Write-Warning -Message "Fresh Installation of Choco.  Please close and open the PowerShell Session so it's in your path then try again." -WarningAction Stop
}

Try {
    $exists = (choco list -l)
    if (!($exists -like "docker *")) {
        choco install docker -y
    }
    if (!($exists -like "docker-machine *")) {
        choco install docker-machine -y
    }
    if (!($exists -like "docker-compose *")) {
        choco install docker-compose -y
    }
}
Catch {
    Write-Error -Message "unable to install docker suite.  Check the logs and try again."
}

#setup Hyper-V in prefered model
# create the external-VSwitch
New-VMSwitch "External-VSwitch" -MinimumBandwidthMode Weight -NetAdapterName "Physical Connection" -AllowManagementOS 0
add-vmnetworkadapter -ManagementOS -name "Host-VMAdapter" -Switchname "External-VSwitch"
Set-vmnetworkadaptervlan -managementOS -VMNetworkAdapterName "Physical Connection" -Access

#create the NAT VSwitch
New-VMSwitch -SwitchName "NAT-VSwitch" -SwitchType Internal
$ifIndex = (get-netadapter "vEthernet (NAT-VSwitch)").ifIndex
New-NetIPAddress -IPAddress 172.16.0.1 -PrefixLength 24 -InterfaceIndex $ifIndex
New-NetNat -Name "NAT-ExternalNet" -InternalIPInterfaceAddressPrefix 172.16.0.0/24

