# Connect to Azure AD, optionally the MSOL Service
# Uses $AdminCredential set in the PowerShell profile via the Get-StoredCredential function

# Connecto to AzureAD
Connect-AzureAD -Credential $AdminCredential

# Connecto to MSOL
Connect-MsolService -Credential $AdminCredential