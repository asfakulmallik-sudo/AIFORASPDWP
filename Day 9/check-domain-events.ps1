Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='WVD-Agent'} -MaxEvents 300 -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -match 'Domain' } |
    Select-Object TimeCreated, Id, Message |
    Format-List
