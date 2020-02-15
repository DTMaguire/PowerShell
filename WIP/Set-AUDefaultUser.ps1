# Updates default user language and region to English Australia
# All new user profiles will be created with these defaults
# Version 1.0 - Copyright DM Tech 2020

New-PSDrive HKU Registry HKEY_USERS
reg load HKU\Default_User C:\Users\Default\NTUSER.DAT

$en_AU = @{
    Locale = '00000C09'
    LocaleName = 'en-AU'
    s1159 = 'AM'
    s2359 = 'PM'
    sCountry = 'Australia'
    sCurrency = '$'
    sDate = '/'
    sDecimal = '.'
    sGrouping = '3;0'
    sLanguage = 'ENA'
    sList = ','
    sLongDate = 'dddd, d MMMM yyyy'
    sMonDecimalSep = '.'
    sMonGrouping = '3;0'
    sMonThousandSep = ','
    sNativeDigits = '0123456789'
    sNegativeSign = '-'
    sPositiveSign = ''
    sShortDate = 'd/MM/yyyy'
    sThousand = ','
    sTime = ':'
    sTimeFormat = 'h:mm:ss tt'
    sShortTime = 'h:mm tt'
    sYearMonth = 'MMMM yyyy'
    iCalendarType = '1'
    iCountry = '61'
    iCurrDigits = '2'
    iCurrency = '0'
    iDate = '1'
    iDigits = '2'
    NumShape = '1'
    iFirstDayOfWeek = '0'
    iFirstWeekOfYear = '0'
    iLZero = '1'
    iMeasure = '0'
    iNegCurr = '1'
    iNegNumber = '1'
    iPaperSize = '9'
    iTime = '0'
    iTimePrefix = '0'
    iTLZero = '0'
}

foreach ($Key in $en_AU.Keys) {
    Set-ItemProperty -Path "HCU:\Default_User\Control Panel\International" -Name $Key -Value $($en_AU.Item($Key))
}

Set-ItemProperty -Path "HKU:\Default_User\Control Panel\International\Geo" -Name Nation -Value 12
Set-ItemProperty -Path "HKU:\Default_User\Control Panel\International\Geo" -Name Name -Value 'AU'
Set-ItemProperty -Path "HKU:\Default_User\Control Panel\International\User Profile" -Name Languages -Value 'en-AU'

if (!(Test-Path -Path "HKU:\Default_User\Control Panel\International\User Profile\en-AU")) {
    New-Item -Path "HKU:\Default_User\Control Panel\International\User Profile\en-AU" -Force
}

New-ItemProperty -Path "HKU:\Default_User\Control Panel\International\User Profile\en-AU" -Name 'CachedLanguageName' -PropertyType String -Value '@Winlangdb.dll,-1107'
New-ItemProperty -Path "HKU:\Default_User\Control Panel\International\User Profile\en-AU" -Name '0C09:00000409' -PropertyType DWord -Value 1

if (Test-Path -Path "HKU:\Default_User\Control Panel\International\User Profile\en-US") {
    Remove-Item -Path "HKU:\Default_User\Control Panel\International\User Profile\en-US" -Recurse -Force
}

reg unload HKU\Default_User
Remove-PSDrive HKU
