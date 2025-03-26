# Убедитесь, что у вас установлен модуль ActiveDirectory
Import-Module ActiveDirectory

# Массив строк
$arrayOfStrings = @("Exchange", "Order", "Public")

# Путь к родительской папке, где будут созданы новые каталоги
$parentFolderPath = "C:\Shared"

# Цикл по каждому элементу массива
foreach ($item in $arrayOfStrings) {
    # Создание пути к новой папке
    $newFolderPath = Join-Path -Path $parentFolderPath -ChildPath $item
    # Создание новой папки
    New-Item -ItemType Directory -Path $newFolderPath -Force

    $groupTypes = @("LIST", "R", "RW")
    foreach ($string in $groupTypes) {
        # Получение текущего ACL папки
        $acl = Get-Acl -Path $newFolderPath
        
        # Формируем имя группы
        $groupName = "FA-" + $item + "_" + $string
        # Создание новой группы в Active Directory
        New-ADGroup -Name $groupName -SamAccountName $groupName -Description "$groupName" -GroupScope Global -Path "OU=FileAccess,OU=ADDS,DC=abc,DC=local"

        # Создание нового правила доступа для группы
        $identity = "$groupName"
        $rights = [System.Security.AccessControl.FileSystemRights]"Modify"
        $type = [System.Security.AccessControl.AccessControlType]::Allow
        $inheritanceFlags = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit,ObjectInherit"
        $propagationFlags = [System.Security.AccessControl.PropagationFlags]"None"
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, $rights, $inheritanceFlags, $propagationFlags, $type)
        # Добавление нового правила в ACL
        $acl.AddAccessRule($rule)
        # Применение измененного ACL к папке
        Set-Acl -Path $newFolderPath -AclObject $acl
    }
}
