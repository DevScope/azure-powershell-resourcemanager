param(        
    [string] $azureProfilePath  = "",
    [string] $azureRunAsConnectionName = "AzureRunAsConnection",    
    $config = @(
        @{
            ResourceGroupName = "RM1";
            ResourceType = "AnalysisServices";
            Name = "asserver1";
            ActiveDays = 1..5;
            ActiveHours = 8..23;
            SKU = "S0"
        }
        ,
        @{
            ResourceGroupName = "RM1";
            ResourceType = "VirtualMachine";
            Name = "VMName";
            ActiveDays = 1..5;
            ActiveHours = 2..5 + 10..23            
        }      
    )
)

$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

Import-Module "AzureRM.AnalysisServices" 
Import-Module "AzureRM.Compute" 

Write-Output "Signing in to Azure..."

# Load the profile from local file
if (-not [string]::IsNullOrEmpty($azureProfilePath))
{    
    Import-AzureRmContext -Path $azureProfilePath | Out-Null
}
# Load the profile from Azure Automation RunAS connection
elseif (-not [string]::IsNullOrEmpty($azureRunAsConnectionName))
{
    $runAsConnectionProfile = Get-AutomationConnection -Name $azureRunAsConnectionName      

    Add-AzureRmAccount -ServicePrincipal -TenantId $runAsConnectionProfile.TenantId `
        -ApplicationId $runAsConnectionProfile.ApplicationId -CertificateThumbprint $runAsConnectionProfile.CertificateThumbprint | Out-Null
}
# Interactive Login
else
{
    Add-AzureRmAccount | Out-Null
}

$currentTime = [TimeZoneInfo]::ConvertTime([DateTime]::UtcNow,[TimeZoneInfo]::FindSystemTimeZoneById("GMT Standard Time"))
$currentDayOfWeek = [Int]($currentTime).DayOfWeek
$currentHour = $currentTime.Hour

Write-Output "CurrentTime: $($currentTime.ToString("yyyy-MM-dd HH:mm:ss"))"

$config |% {

    $resourceConfig = $_

    if ($resourceConfig.ResourceType -eq "AnalysisServices")
    {
        Write-Output "Configuring Analysis Services Server '$($resourceConfig.Name)'"

        # Get the server status

        $asServer = Get-AzureRmAnalysisServicesServer -ResourceGroupName $resourceConfig.ResourceGroupName -Name $resourceConfig.Name

        if ($asServer)
        {
            Write-Output "Current Azure AS '$($asServer.Name)' status: $($asServer.State)"

            # Check if should be enabled

            $match = ($resourceConfig.ActiveDays -contains $currentDayOfWeek -and $resourceConfig.ActiveHours -contains $currentHour)

            if ($match)
            {
                # If paused then Resume

                if($asServer.State -eq "Paused")
                {
                    Write-Output "Resuming AS Server"

                    $asServer | Resume-AzureRmAnalysisServicesServer
                }         

                 # Change the SKU if needed
    
                if($asServer.Sku.Name -ne $resourceConfig.Sku){

                    Write-Output "Updating AS server from $($asServer.Sku.Name) to $($resourceConfig.Sku)"
                 
                    Set-AzureRmAnalysisServicesServer -Name $asServer.Name -ResourceGroupName $resourceConfig.ResourceGroupName -Sku $resourceConfig.Sku
                }           
            }
            else
            {
                Write-Output "Pausing AS Server"

                $asServer | Suspend-AzureRmAnalysisServicesServer -Verbose
            }            
        }
        else
        {
            Write-Output "Cannot find Azure AS Server"
        }
    }
    elseif ($resourceConfig.ResourceType -eq "VirtualMachine")
    {
        Write-Output "Configuring VM '$($resourceConfig.Name)'"

        $vm = Get-AzureRmVM -ResourceGroupName $resourceConfig.ResourceGroupName -Name $resourceConfig.Name -Status

        $match = ($resourceConfig.ActiveDays -contains $currentDayOfWeek -and $resourceConfig.ActiveHours -contains $currentHour)

        $running = @($vm.Statuses |? Code -eq "Powerstate/Running").Count -gt 0

        Write-Output "VM Running: '$running'"        

        if ($match)
        {            
            if (-not $running)
            {
                Write-Output "Starting VM"

                $status = $vm | Start-AzureRmVM
            }                        
        }
        else
        {
            if ($running)
            {
                Write-Output "Stopping VM"

                $status = $vm | Stop-AzureRmVM -Force
            }                 
        }
    }
}
