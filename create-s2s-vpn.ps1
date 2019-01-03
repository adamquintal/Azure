<#
.DESCRIPTION
    Creates a new vNet that utilizes the Site-to-Site vNet we have configured within Azure.

.PARAMETER AccountName
    What account will this vNet be used for? If you input "adam" as the parameter the resources will be created as waters-adam-rg & waters-adam-vnet.
    waters-<AccountName>-s2s-vpn-rg & waters-<AccountName>-s2s-vpn-vnet

.PARAMETER VnetAddress
    The address for the entire vNet. Example: 10.243.8.0/24

.PARAMETER VnetSubnetAddress
    The subnet for the vNet. Example: 10.243.8.0/25

.EXAMPLE
    New-WatersAzureVnet -AccountName "adam" -VnetAddress 10.243.8.0/24 -VnetSubnetAddress 10.243.8.0/25

.NOTES
    AUTHOR: Adam Quintal
    LASTEDIT: JAN 2, 2019

#>
param (
       [Parameter(Mandatory=$true)][string]$AccountName,
       [Parameter(Mandatory=$true)][string]$VnetAddress,
       [Parameter(Mandatory=$true)][string]$VnetSubnetAddress,
       [Parameter(Mandatory=$false)][string]$Dns
)
<# The New-WatersAzureVnet function creates a vNet that is hosted on the Waters Site-to-Site VPN connection #>
function New-WatersAzureVnet {
    [cmdletbinding()]
    param(
       [Parameter(Mandatory=$true)][string]$AccountName,
       [Parameter(Mandatory=$true)][string]$VnetAddress,
       [Parameter(Mandatory=$true)][string]$VnetSubnetAddress,
       [Parameter(Mandatory=$false)][string]$Dns
       
    )
 
    <# Request input from user for which subscription the vNet should be created in #>

     $listOfSubscriptions = Get-AzSubscription
     $listOfSubscriptions | Format-List -Property Name
     $subscription = Read-Host "Please select a subscription from above that you would like this vNet created in"   

    while ($subscription -notin $listofSubscriptions.Name)
    {
        Write-Host
        Write-Host "Invalid choice, please select a valid subscription!" -ForeGroundColor Red
        $listOfSubscriptions = Get-AzSubscription
        $listOfSubscriptions | Format-List -Property Name
        $subscription = Read-Host "Please select a subscription from above that you would like this vNet created in"      
    }

    Select-AzSubscription -Subscription $subscription

    <# Create resource group #>
    $RGName = "waters-$AccountName-s2s-vpn-rg"
    $VnetName = "waters-$AccountName-s2s-vpn-vnet"
    # Try/Catch the RG name
    Write-Host "Creating a resource group called $RGName"
    New-AzResourceGroup -Name waters-$AccountName-s2s-vpn-rg -Location EastUS
    <# Create vNet #>
    Write-Host "Creating a virtual network called $VnetName"
    $virtualNetwork = New-AzVirtualNetwork -ResourceGroupName $RGName -Location EastUS -Name $VnetName -AddressPrefix $VnetAddress -DnsServer $dns
    <# Create Subnet #>
    Add-AzVirtualNetworkSubnetConfig -Name "$AccountName-subnet-dev" -AddressPrefix $VnetSubnetAddress -VirtualNetwork $virtualNetwork

    <# Associate subnet to vNet #>
    $virtualNetwork | Set-AzVirtualNetwork

    <# Create vNet peering #>
    try
    {
    Write-Host "Peering $AccountName vNet to Gateway vNet"
    Add-AzVirtualNetworkPeering -Name waters-s2s-vpn-peer-to-hub -VirtualNetwork $virtualNetwork -RemoteVirtualNetworkId <# Remote ID of hub vNet goes here#> -UseRemoteGateways -AllowForwardedTraffic
    }
    catch{Write-Host "Peering for this vNet has already been established. Moving on..."}

    Write-Host "Switching to gateway vnet subscription"
    Select-AzSubscription waters-informatics-master

    try
    {
    Write-Host "Peering Gateway vNet to $AccountName vNet"
    $gatewayVnet = Get-AzVirtualNetwork -Name s2s-vpn-vnet -ResourceGroupName s2s-vpn-rg
    Add-AzVirtualNetworkPeering -Name s2s-vpn-peer-to-$AccountName -VirtualNetwork $gatewayVnet -RemoteVirtualNetworkId $virtualNetwork.Id -AllowGatewayTransit -AllowForwardedTraffic 
    }
    catch{Write-Host "Peering for this vNet has already been established. Moving on..."}

    <# Insert Resource Locks here for the newly created resource group #>
    Select-AzSubscription $subscription
    Write-Host "Placing a lock on $RGName"
    New-AzResourceLock -LockName "$AccountName-s2s-vpn-delete-lock" -LockLevel CanNotDelete -ResourceGroupName $RGName -Force
    New-AzResourceLock -LockName "$AccountName-s2s-vpn-read-only-lock" -LockLevel ReadOnly -ResourceGroupName $RGName -Force

    Write-Host "The vNet $VnetName has been created, and is now available for deployment." -ForeGroundColor Green
}

New-WatersAzureVnet -AccountName $AccountName -VnetAddress $VnetAddress -VnetSubnetAddress $VnetSubnetAddress
