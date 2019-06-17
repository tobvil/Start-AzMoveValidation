<#
.Synopsis
   Start-AzMoveValidation.ps1 - Validates whether resources can be moved from one resource group to another resource group.
.DESCRIPTION
   This function checks whether the specified resources can be moved to the target. The resources to move must be in the same source resource group. The target resource group may be in a different subscription
.EXAMPLE
   Start-AzMoveValidation -TargetSubscriptionId 'SubscriptionId' -TargetResourceGrup 'Resource group name' -SourceSubscriptionId 'SubscriptionId' -SourceResourceGroup 'Resource group name' -SourceTenantId 'TenantId'
.NOTES
   Written by Tobias Vilhelmsen
#>

function Start-AzMoveValidation {
    
    param (

        [Parameter(Mandatory = $True)]
        [string]
        $TargetSubscriptionId,

        [Parameter(Mandatory = $True)]
        [string]
        $TargetResourceGroup,

        [Parameter(Mandatory = $True)]
        [string]
        $SourceSubscriptionId, 
 
        [Parameter(Mandatory = $True)]
        [string]
        $SourceResourceGroup,

        [Parameter(Mandatory = $True)]
        [string]
        $SourceTenantId
    )
    begin {

        $ErrorActionPreference = 'Stop'

        #Checks if Az module is installed
        if (!(Get-Module -ListAvailable Az.Accounts)) {
            Write-Output "Installing Az module"
            Install-Module -Name Az -Force -AllowClobber -Scope 'CurrentUser'
        }
        
        #checks if session to subscription already exists
        $null = $azContext = Get-AzContext
        
        #Connects to Azure
        if (!([string]$azContext.Subscription -eq $SourceSubscriptionId) -and (!([string]$azContext.Tenant -eq $SourceTenantId))) {
        $null = Connect-AzAccount -SubscriptionId $SourceSubscriptionId -TenantId $SourceTenantId
        }
    }
    process {

        #Gets all parent resources in resource group
        $azResources = Get-AzResource -ResourceGroupName $SourceResourceGroup | Where-Object ParentResource -EQ $null | Select-Object ResourceId

        #Get Bearer token for authentication to Azure API
        $currentAzureContext = Get-AzContext
        $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
        $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
        $token = $profileClient.AcquireAccessToken($currentAzureContext.Subscription.TenantId).AccessToken

        #Creates body with resouces and targets
        $body = @{
            resources           = @($azResources.ResourceId)
            targetResourceGroup = "/subscriptions/$TargetSubscriptionId/resourceGroups/$TargetResourceGroup"
        } | ConvertTo-Json

        $header = @{
            authorization = "Bearer $token"
        }

        #Creates params to invoke webrequest
        $postParams = @{
            Method      = 'Post'
            Uri         = "https://management.azure.com/subscriptions/$SourceSubscriptionId/resourceGroups/$SourceResourceGroup/validateMoveResources?api-version=2019-05-01"
            Body        = $body
            ContentType = 'Application/json'
            Headers     = $header
        }

        #Posts resources for move validation
        $post = Invoke-WebRequest @postParams -UseBasicParsing

        #Assigns variable to location url where we get validation result
        $location = $post.Headers.Location

        do {
            try {
                
                #Gets validation result
                $get = Invoke-WebRequest -Method 'Get' -Uri "$location" -Headers $header -UseBasicParsing

            } catch {

                $_.ErrorDetails | Format-List *
                return

            }

            #Checks if result is ready, or waits until next retry is possible 
            if ($get.StatusCode -eq 202) {

                $retry = $get.Headers.'Retry-After'
                Start-Sleep -Seconds $retry[0]

            }

        } until ($get.StatusCode -eq 204)

        Write-Output 'Move operation validated successfully'

    }
    end {

        #Disconnects from Azure
        $null = Disconnect-AzAccount

    }
}