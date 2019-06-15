# Start-AzMoveValidation


#####   Start-AzMoveValidation.ps1 - Validates whether resources can be moved from one resource group to another resource group.

# DESCRIPTION
   This function checks whether the specified resources can be moved to the target. The resources to move must be in the same source resource group. The target resource group may be in a different subscription.

# EXAMPLE
   Start-AzMoveValidation -TargetSubscriptionId 'SubscriptionId' -TargetResourceGrup 'Resource group name' -SourceSubscriptionId 'SubscriptionId' -SourceResourceGroup 'Resource group name' -SourceTenantId 'TenantId'

# Output Example
Move operation validated successfully

Or

Message:{"error":{"code":"ResourceMoveNotSupported","message":"Resource move is not supported for resource types 'microsoft.insights/metricalerts'."}}