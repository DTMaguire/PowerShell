########################
# CheckADCredentials.ps1
# DTM - 2018
########################

Function Test-ADAuthentication {
    param($userlogin,$userpassword)
    (new-object directoryservices.directoryentry "",$userlogin,$userpassword).psbase.name -ne $null
}

Clear-Host

# Prompt user to enter account details
$login = Read-Host 'Enter user name:'
$password = Read-Host 'Enter password:'

if (Test-ADAuthentication $login $password){
    Write-Host "Valid credentials" -ForegroundColor Green
}
else{
    Write-Host "Invalid credentials" -ForegroundColor Red
}