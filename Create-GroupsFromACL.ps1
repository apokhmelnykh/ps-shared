param (
    [Parameter(Mandatory=$true)]
    [string]$dirRootPath, # Корневая директория, от которой будем сканировать

    [Parameter(Mandatory=$false)]
    [int]$dirScanLevel = 4, # Глубина сканирования

    [Parameter(Mandatory=$false)]
    [string]$groupNameLike = '*FA*', # Фильтр по имени группы

    [Parameter(Mandatory=$false)]
    [string]$csvPath, # Путь до файла с группами AD для переноса

    [Parameter(Mandatory=$false)]
    [string]$dstDomainController = 'spbadc001', # TODO! Контроллер домена на котором будем создавать группы

    [Parameter(Mandatory=$false)]
    [string]$dstOU, # DN в котором будем создавать группы безопасности в целевом домене

    [Parameter(Mandatory=$false)]
    [switch]$csvOnly # если задан, то только выгружаем группы в CSV
)

# Проверка обязательных параметров
if ([string]::IsNullOrWhiteSpace($dirRootPath)) {
    Write-Error "Parameter -dirRootPath is required."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($dstOU) -and !($csvOnly)) {
    Write-Error "Parameter -dstOU is required."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($csvPath)) {
    $csvPath = "groups-$(Get-Date -Format yyyyMMddHHmmss).csv"
}

# Массивы для хранения данных
$groupsFromACL      = @() # Массив групп полученных из ACL
$groupsFromAD       = @() # Массив групп полученных из AD

Write-Host -BackgroundColor DarkGreen "Block1. Get security groups from ACL."

# Получим массив с директориями вложенными в корневую директорию
$dirCollected = Get-ChildItem -Directory -Recurse -Path $dirRootPath -Depth $dirScanLevel

# В этом цикле обработаем директории, чтобы извлечь из них имена групп AD для управления доступом
foreach ($dir in $dirCollected) {
    $path = $dir.FullName
    # Запрос на поиск групп AD в ACL директории
    $groupsFromPath = ((Get-Acl $path).Access | Where-Object {($_.IsInherited -eq $false) -and ($_.IdentityReference -like $groupNameLike)}).IdentityReference

    # В этом цикле обработаем группы AD. Сохраним уникальные группы для дальнейшей обработки
    foreach ($group in $groupsFromPath) {
        $groupName = $group.ToString()
        if ($groupsFromACL.Contains($groupName)) {
            Write-Output "- group already exist: $group"
        } else {
            $groupsFromACL += $groupName
            Write-Output "+ group added: $group"
        }
    }
}

# Импорт модуля Active Directory
Import-Module ActiveDirectory

# Запросим информацию о группах из AD
foreach ($group in $groupsFromACL) {
    # Переопределим группу, отбросим имя домена
    $group = ($group.Split('\'))[1]
    # Запрос к AD
    $groupAD = Get-ADGroup -Filter {Name -eq $group} -Properties Description
    # Супер популярный прием, чтобы не городить селекты и фильтры просто создадим свой объект с нужными нам свойствами. Очень часто используется.
    $groupInfo = [PSCustomObject]@{
        GroupName   = $groupAD.Name
        Description = $groupAD.Description
    }
    # Сохраним информацию о группе полученную из AD
    $groupsFromAD += $groupInfo
}

# Экспорт данных о группах в CSV файл
$groupsFromAD | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

# Завершаем работу скрипта если задан параметр csvOnly
if ($csvOnly) {
    exit
}

Write-Host -BackgroundColor DarkGreen "Block2. Create new groups in the target domain."
$credential = Get-Credential -Message "Authorize for target domain"

try {
    $session = New-PSSession -ComputerName $dstDomainController -Credential $credential
    Invoke-Command -Session $session -ScriptBlock {
        param($groupsFromAD, $dstOU)
        foreach ($group in $groupsFromAD) {
            try {
                New-ADGroup -GroupScope Global -Name $group.GroupName -Description $group.Description -Path $dstOU
                Write-Host "+ Group $($group.GroupName) added."
            } catch {
                Write-Host "- Can't add group $($group.GroupName): $_"
            }
        }
    } -ArgumentList $groupsFromAD, $dstOU
} catch {
    Write-Host "- Can't connect to AD domain: $_"
} finally {
    if ($session) {
        Remove-PSSession -Session $session
    }
}
