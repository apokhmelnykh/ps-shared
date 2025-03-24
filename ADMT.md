![Схема теста](admt.png)
# Миграция групп с ADMT
## 1. Подготовка стенда
Узлы на стенде:
* dc01.abc.local - контроллер в домене из которого переносим группы (старый домен)
* dc01.xyz.local - контроллер домена в который переносим группы (новый домен)
* admt01.xyz.local - сервер с установленным ADMT (новый домен)

### Подготовка сервера 'dc01.abc.local'  
Адрес: 172.16.4.11
```
#
# Windows PowerShell script for AD DS Deployment
#

Import-Module ADDSDeployment
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\ADDS\NTDS" `
-DomainMode "WinThreshold" `
-DomainName "abc.local" `
-DomainNetbiosName "ABC" `
-ForestMode "WinThreshold" `
-InstallDns:$true `
-LogPath "C:\ADDS\LOG" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\ADDS\SYSVOL" `
-Force:$true
```

Скрипт для создания директорий и групп доступа
```
.\Add-FoldersAndGroups.ps1
```

Настройка траста - DNS
```
Add-DnsServerConditionalForwarderZone -Name "xyz.local" -MasterServers 172.16.5.11 -ReplicationScope "Forest"

New-NetFirewallRule -DisplayName "_any" -Direction Inbound -RemoteAddress 172.16.5.0/24 -Action Allow

# проверка
ping xyz.local
```

### Подготовка сервера 'dc01.xyz.local'  
Адрес: 172.16.5.11
```
#
# Windows PowerShell script for AD DS Deployment
#

Import-Module ADDSDeployment
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\ADDS\NTDS" `
-DomainMode "WinThreshold" `
-DomainName "xyz.local" `
-DomainNetbiosName "XYZ" `
-ForestMode "WinThreshold" `
-InstallDns:$true `
-LogPath "C:\ADDS\LOG" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\ADDS\SYSVOL" `
-Force:$true
```

Настройка траста - DNS
```
Add-DnsServerConditionalForwarderZone -Name "abc.local" -MasterServers 172.16.4.11 -ReplicationScope "Forest"

New-NetFirewallRule -DisplayName "_any" -Direction Inbound -RemoteAddress 172.16.4.0/24 -Action Allow

# проверка
ping abc.local
```
Настройка траста
```
# Нет PowerShell команд
# Делаем вручную
# Проверка созданного траста
Get-ADTrust -Filter *
```

### Подготовка сервера 'admt01.xyz.local'  
Установить MSSQLExpress2022
Установить ADMT3.2
Нужный нам для работы исполняемый файл
```
C:\Windows\ADMT\admt.exe
```


## 1. Создаем список групп на миграцию и сохраняем в формате *.csv
На хосте `dc01.abc.local` запускаем скрипт с сключом `-csvOnly`.
```
.\Create-GroupsFromACL.ps1 -dirRootPath C:\Shared\ -csvOnly -groupNameLike "*FA*"
```
## 2.