function Get-DisksSmart {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Computers,       # Принимаем один или несколько серверов

        [switch]$SaveFile           # Сохранит результат запроса в $env:USERPROFILE\Documents\DisksSmart
    )

    # Создаем массив для хранения результатов всех серверов
    $allrequests = @()

    foreach ($computer in $Computers) {
        # Write-Host "Обработка сервера: $computer"
        # Проверяем доступность сервера
        if (-not (Test-Connection -ComputerName $computer -Count 1 -Quiet)) {
            Write-Warning "Сервер $computer недоступен."
            continue
        }

        # Определяем блок скрипта для выполнения на удаленном сервере
        $scriptBlock = {
            # Убедитесь, что smartctl.exe установлен и доступен в PATH
            if (-not (Get-Command smartctl.exe -ErrorAction SilentlyContinue)) {
                throw "Утилита smartctl.exe не найдена на сервере $env:COMPUTERNAME."
            }

            # Выполняем команду smartctl --scan --json для получения списка дисков
            $scanJson = & smartctl.exe --scan --json | ConvertFrom-Json

            # Создаем массив для хранения данных
            $diskInfoArray = @()

            foreach ($device in $scanJson.devices) {
                $devicePath = $device.name
                $deviceType = $device.type

                # Выполняем команду smartctl с опцией --json для получения информации о диске
                $smartctlJson = & smartctl.exe -a -d $deviceType --json $devicePath | ConvertFrom-Json

                # Парсим статус SMART
                # TODO! проверить какие значения может возвращать
                $smartStatus = if ($smartctlJson.smart_status.passed -eq $true) {
                    "PASSED"
                } elseif ($smartctlJson.smart_status.passed -eq $false) {
                    "FAILED"
                } else {
                    "Unknown"
                }

                # Парсим количество записанных байт (Host_Writes)
                $hostWrites = if ($smartctlJson.nvme_smart_health_information_log.data_units_written) {
                    [int64]$smartctlJson.nvme_smart_health_information_log.data_units_written * 1000 * 512  # Преобразуем в байты
                } elseif ($smartctlJson.ata_smart_attributes.table | Where-Object { $_.name -eq "Host_Writes" }) {
                    [int64]($smartctlJson.ata_smart_attributes.table | Where-Object { $_.name -eq "Host_Writes" }).raw.value * 1MB
                } else {
                    0
                }

                # Парсим количество прочитанных байт (Host_Reads)
                $hostReads = if ($smartctlJson.nvme_smart_health_information_log.data_units_read) {
                    [int64]$smartctlJson.nvme_smart_health_information_log.data_units_read * 1000 * 512  # Преобразуем в байты
                } elseif ($smartctlJson.ata_smart_attributes.table | Where-Object { $_.name -eq "Host_Reads" }) {
                    [int64]($smartctlJson.ata_smart_attributes.table | Where-Object { $_.name -eq "Host_Reads" }).raw.value * 1MB
                } else {
                    0
                }

                # Парсим серийный номер
                $serialNumber = if ($smartctlJson.serial_number) {
                    $smartctlJson.serial_number.Trim()
                } else {
                    "Unknown"
                }

                # Парсим модель диска
                $model = if ($smartctlJson.model_name) {
                    $smartctlJson.model_name.Trim()
                } else {
                    "Unknown"
                }

                # Создаем объект с данными о диске
                $diskInfo = [PSCustomObject]@{
                    Hostname    = $env:COMPUTERNAME  # Имя текущего сервера
                    Disk        = $devicePath
                    Type        = $deviceType
                    Model       = $model
                    SMART       = $smartStatus
                    WritesGB    = [math]::Round($hostWrites / 1GB, 1)  # Округляем до ГБ
                    ReadsGB     = [math]::Round($hostReads / 1GB, 1)   # Округляем до ГБ
                }

                # Добавляем объект в массив
                $diskInfoArray += $diskInfo
            }

            return $diskInfoArray
        }

        try {
            # Запускаем блок скрипта на удаленном сервере
            $request = Invoke-Command -ComputerName $computer -ScriptBlock $scriptBlock -HideComputerName

            # Добавляем результаты текущего сервера в общий массив
            $returnObject += $request | Select-Object -Property * -ExcludeProperty RunspaceId
            # Write-Host "Данные загружены: $computer"
        } catch {
            Write-Warning "Не удалось выполнить команду на сервере $computer. Ошибка: $_"
        }
    }

    if($SaveFile) {
        $path = "$env:USERPROFILE\Documents\DisksSmart"
        $fileName = "$(Get-Date -Format yyyyMMdd_hhmmss).csv"
        $filePath = "$path\$fileName"
        if (-not (Test-Path $path)) {
            try {
                New-Item -ItemType Directory -Path $path -ErrorAction SilentlyContinue
            } catch {
                Write-Warning "Ошибка при создании директории: $_"
            }
        }
        try {
            $returnObject | Export-Csv -NoClobber -NoTypeInformation -Path $filePath
        } catch {
            Write-Warning "Ошибка при создании файла: $_"
        }
    }
    return $returnObject
}