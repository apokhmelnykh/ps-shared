# Get-DisksSmart
Cканирует диски на указанном сервере и выводит результат в файл.  
Параметры:  
- `Computers` сервер(ы) которые будут просканированны
- `SaveFile` сохранить результат в файл CSV


## Предварительная настройка

Установить [smartmontools](https://www.smartmontools.org/) на все узлы, которые необходимо сканировать.  
Добавить  путь до `smartctl.exe` в переменную окружения PATH.  

Создание профиля PowerShell
```
New-Item -Type File $PROFILE -Force
```

Добавьте следующее содержимое в файл $PROFILE
```
. $env:USERPROFILE\PSScripts\*
```

Создайте каталог и сохраните в нем файл Get-DisksSmart.ps1
```
New-Item -Type Directory $env:USERPROFILE\PSScripts -Force
$file = Invoke-WebRequest -Uri https://raw.githubusercontent.com/apokhmelnykh/ps-shared/refs/heads/main/Get-DisksSmart/Get-DisksSmart.ps1
$file.Content | Out-File -Encoding UTF8 -FilePath "$env:USERPROFILE\PSScripts\Get-DisksSmart.ps1"
```

Для удобства можно создать постоянную переменную в профиле и сохранить в нее имена серверов.  
Добавьте следующее содержимое в файл $PROFILE  
```
$hwservers = @(
    "hv01"
    "hv02"
    "hv03"
)
```