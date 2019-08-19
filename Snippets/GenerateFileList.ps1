# Generates a list of files with a specified extension and saves them into a text document
# Used to get a list of map names for KF2 to specify on the command line when launching a local server

Get-ChildItem -Recurse *.kfm | ForEach-Object {($_.Name).Replace('.txt','')} | Out-File TxtFiles.txt