# Connect to Azure AD, optionally the MSOL Service
# Uses $AdminCredential set in the PowerShell profile via the Get-StoredCredential function

#Requires -Modules AzureAD

# Connect to AzureAD
Connect-AzureAD -Credential $AdminCredential

# Connect to MSOL
#Connect-MsolService -Credential $AdminCredential