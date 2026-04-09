# 数据提取脚本 - 从 MedicineDatabase.ets 提取数据生成 JSON
$sourceFile = "C:\tjc\app-harmony-os\app-medication\entry\src\main\ets\services\MedicineDatabase.ets"
$outputDir = "C:\tjc\app-harmony-os\app-medication\entry\src\main\resources\rawfile"

# 读取源文件
$content = Get-Content $sourceFile -Raw

# 提取 medicineDb 数组内容
$medicineDbStart = $content.IndexOf("private static medicineDb: MedicineInfo[] = [")
$medicineDbEnd = $content.IndexOf("];", $medicineDbStart)
$medicineDbContent = $content.Substring($medicineDbStart + "private static medicineDb: MedicineInfo[] = [".Length, $medicineDbEnd - $medicineDbStart - "private static medicineDb: MedicineInfo[] = [".Length)

# 解析药品数据
$medicines = @()
$pattern = "\{ name: '([^']+)', aliases: \[([^\]]*)\], pinyin: '([^']+)', category: '([^']+)', commonDosageForms: \[([^\]]*)\] \}"
$matches = [regex]::Matches($medicineDbContent, $pattern)

foreach ($match in $matches) {
    $name = $match.Groups[1].Value
    $aliasesStr = $match.Groups[2].Value
    $pinyin = $match.Groups[3].Value
    $category = $match.Groups[4].Value
    $dosageFormsStr = $match.Groups[5].Value

    # 解析别名
    $aliases = @()
    if ($aliasesStr.Trim()) {
        $aliases = $aliasesStr -split "','" | ForEach-Object { $_ -replace "'", "" -replace "^\s+|\s+$", "" } | Where-Object { $_ }
    }

    # 解析剂型
    $dosageForms = @()
    if ($dosageFormsStr.Trim()) {
        $dosageForms = $dosageFormsStr -split "','" | ForEach-Object { $_ -replace "'", "" -replace "^\s+|\s+$", "" } | Where-Object { $_ }
    }

    $medicines += @{
        name = $name
        aliases = $aliases
        pinyin = $pinyin
        category = $category
        commonDosageForms = $dosageForms
    }
}

Write-Host "Extracted $($medicines.Count) medicines"

# 提取 ASR 纠错映射
$asrCorrectionMap = @{}
$asrPattern = "\['([^']+)', '([^']+)'\]"
$asrContent = $content.Substring($content.IndexOf("private static asrCorrectionMap: Map<string, string> = new Map(["))
$asrContent = $asrContent.Substring(0, $asrContent.IndexOf("]);"))
$asrMatches = [regex]::Matches($asrContent, $asrPattern)

foreach ($match in $asrMatches) {
    $asrCorrectionMap[$match.Groups[1].Value] = $match.Groups[2].Value
}

Write-Host "Extracted $($asrCorrectionMap.Count) ASR corrections"

# 提取 charToInitial 映射
$charToInitial = @{}
$charPattern = "\['([^']+)', '([^']+)'\]"
$charContent = $content.Substring($content.IndexOf("private static charToInitial: Map<string, string> = new Map(["))
$charContent = $charContent.Substring(0, $charContent.IndexOf("]);"))
$charMatches = [regex]::Matches($charContent, $charPattern)

foreach ($match in $charMatches) {
    $charToInitial[$match.Groups[1].Value] = $match.Groups[2].Value
}

Write-Host "Extracted $($charToInitial.Count) char-to-initial mappings"

# 提取 homophoneMap
$homophoneMap = @{}
$homoPattern = "\['([^']+)', \[([^\]]+)\]\]"
$homoContent = $content.Substring($content.IndexOf("private static homophoneMap: Map<string, string[]> = new Map(["))
$homoContent = $homoContent.Substring(0, $homoContent.IndexOf("]);"))
$homoMatches = [regex]::Matches($homoContent, $homoPattern)

foreach ($match in $homoMatches) {
    $key = $match.Groups[1].Value
    $valuesStr = $match.Groups[2].Value
    $values = $valuesStr -split "','" | ForEach-Object { $_ -replace "'", "" -replace "^\s+|\s+$", "" } | Where-Object { $_ }
    $homophoneMap[$key] = @($values)
}

Write-Host "Extracted $($homophoneMap.Count) homophone mappings"

# 生成 JSON 文件
$medicineJson = @{
    version = "2026.04.05"
    totalCount = $medicines.Count
    medicines = $medicines
    asrCorrections = $asrCorrectionMap
    charToInitial = $charToInitial
    homophoneMap = $homophoneMap
}

$jsonContent = $medicineJson | ConvertTo-Json -Depth 10 -Compress:$false
$jsonContent | Out-File -FilePath "$outputDir\medicine_base.json" -Encoding UTF8

Write-Host "Generated medicine_base.json at $outputDir"

# 生成版本信息文件
$versionJson = @{
    localVersion = "2026.04.05"
    serverVersion = "2026.04.05"
    lastSyncTime = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    incrementalUpdates = @()
}
$versionJson | ConvertTo-Json | Out-File -FilePath "$outputDir\medicine_version.json" -Encoding UTF8

Write-Host "Generated medicine_version.json at $outputDir"
Write-Host "Phase 1 complete!"