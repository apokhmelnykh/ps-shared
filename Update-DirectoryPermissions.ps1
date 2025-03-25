function Update-DirectoryPermissions {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,

        [Parameter(Mandatory = $true)]
        [string]$SrcDomain,
                
        [Parameter(Mandatory = $true)]
        [string]$DstDomain
    )

    # Проверяем наличие директории
    if (-not (Test-Path -Path $DirectoryPath)) {
        Write-Error "- Folder '$DirectoryPath' not exist."
        return
    }

    # Получаем корневую директорию и все поддиректории
    $directories = @(Get-Item -Path $DirectoryPath)
    $directories += @(Get-ChildItem -Path $DirectoryPath -Recurse -Directory)

    # Обходим директории
    foreach ($dir in $directories) {
        # Получаем текущий ACL директории
        $acl = Get-Acl -Path $dir.FullName
        # Проходим по всем ACE в ACL
        foreach ($ace in $acl.Access) {
            # Проверяем, что ACE не унаследованная
            if (-not $ace.IsInherited) {
                # Проверяем, что ACE относится к объекту домена
                if ($ace.IdentityReference -match "^$SrcDomain\\") {
                    # Извлекаем имя объекта без домена
                    $groupName = ($ace.IdentityReference -split '\\')[1]
                    # Формируем новое имя объекта в целевом домене
                    # нет смысла ходить в целевой домен и проверять наличие там этого объекта
                    # если объект есть, то он добавится в ACL
                    # если объекта нет, то ACL не будет изменен
                    $newGroupName = "$DstDomain\$groupName"
                    # Создаем новую ACE с теми же правами, но для нового домена
                    $newAce = New-Object System.Security.AccessControl.FileSystemAccessRule(
                        $newGroupName,
                        $ace.FileSystemRights,
                        $ace.InheritanceFlags,
                        $ace.PropagationFlags,
                        $ace.AccessControlType
                    )
                    # Добавляем новую ACE в ACL
                    $acl.AddAccessRule($newAce)
                }
            }
        }
        # Применяем измененный ACL к директории
        Set-Acl -Path $dir.FullName -AclObject $acl
        Write-Host "+ Directory Permissions updated: $($dir.FullName)"
    }
}
