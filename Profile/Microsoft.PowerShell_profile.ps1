# This is the default profile loaded by PowerShell upon launch
# It's normally located under: C:\Users\(UserName)\Documents\WindowsPowerShell
# - or for PowerShell Core (v6+): C:\Users\(UserName)\Documents\PowerShell
#
# This file is just used for setting the user-scope environment variable and launching the main script
# Because I'm using multiple accounts, I just copy this into the location above for each one
# Customisations are then handled in the shared script
#
# I'm using this method instead of a global profile as to not impact any other user accounts

# Enter UPN of an Admin account for connecting to Office 365 with stored credentials
$env:AdminUPN = ' '

# Call the shared script from a common directory
. "D:\Scripts\PowerShell\Profile\DM-PowerShell_Profile.ps1"