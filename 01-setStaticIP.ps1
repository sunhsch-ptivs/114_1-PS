# ===============================
#  Windows Server 2022 - 設定固定 IP 位址
#  根據 113 年工科技藝競賽要求
# ===============================
# 驗證輸入
    # 提示使用者輸入崗位編號
    $XX = Read-Host "請輸入崗位編號（例如：01）"  # 取得崗位編號用於組成 IP 位址
    # 檢查輸入是否為空
    $XXNum = $XX -replace '^0+', ''  # 使用正規表示式移除前導零，將 01 轉換為 1
    if ([string]::IsNullOrWhiteSpace($XXNum)) {  # 若輸入為空或格式錯誤（輸入為 01）則設為 1 
    $XXNum = "1" 
    Write-Host "使用預設崗位編號：01" -ForegroundColor Yellow  # 以黃色顯示使用預設值訊息
    }    
# 組合 IP 位址
$IPAddress = "172.16.$XXNum.254"  # 設定伺服器 IP 位址為 172.16.XX.254
$PrefixLength = 24  # 設定子網路遮罩長度為 24 位元（相當於 255.255.255.0）
$Gateway = "172.16.$XXNum.1"  # 設定預設閘道為 172.16.XX.1
$DNSServer = "127.0.0.1"  # 設定 DNS 伺服器為本機（127.0.0.1），因為此伺服器將成為網域控制站

# 顯示即將設定的資訊
Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  即將設定固定 IP 位址" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  IP 位址：$IPAddress"  # 顯示 IP 位址
Write-Host "  子網路遮罩：255.255.255.0 (/$PrefixLength)"  # 顯示子網路遮罩
Write-Host "  預設閘道：$Gateway"  # 顯示預設閘道
Write-Host "  DNS 伺服器：$DNSServer"  # 顯示 DNS 伺服器
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# 確認是否繼續
$Confirm = Read-Host "是否繼續設定？(Y/N)"  # 要求使用者確認

if ($Confirm -ne 'Y' -and $Confirm -ne 'y') {  # 若使用者未輸入 Y 或 y
    Write-Host "❌ 已取消設定作業" -ForegroundColor Red  # 顯示取消訊息
    exit  # 結束腳本
}

# 取得網路介面卡
Write-Host "`n正在取得網路介面卡資訊..." -ForegroundColor Cyan  # 顯示進度訊息
$Adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1  # 取得第一個啟用狀態的網路介面卡

if ($null -eq $Adapter) {  # 檢查是否找到網路介面卡
    Write-Host "❌ 錯誤：找不到可用的網路介面卡！" -ForegroundColor Red  # 顯示錯誤訊息
    exit  # 結束腳本
}

$InterfaceAlias = $Adapter.Name  # 取得網路介面卡的名稱（別名）
Write-Host "使用網路介面卡：$InterfaceAlias" -ForegroundColor Green  # 顯示使用的網路介面卡

# 移除現有的 IP 設定（如果有 DHCP 或其他設定）
Write-Host "正在移除現有的 IP 設定..." -ForegroundColor Cyan  # 顯示進度訊息
Remove-NetIPAddress -InterfaceAlias $InterfaceAlias -Confirm:$false -ErrorAction SilentlyContinue  # 移除現有 IP 位址，不顯示確認提示和錯誤訊息
Remove-NetRoute -InterfaceAlias $InterfaceAlias -Confirm:$false -ErrorAction SilentlyContinue  # 移除現有路由，不顯示確認提示和錯誤訊息

# 設定新的固定 IP 位址
Write-Host "正在設定固定 IP 位址..." -ForegroundColor Cyan  # 顯示進度訊息
New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway | Out-Null  # 設定新的 IP 位址、子網路遮罩和預設閘道

# 設定 DNS 伺服器
Write-Host "正在設定 DNS 伺服器..." -ForegroundColor Cyan  # 顯示進度訊息
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSServer  # 設定 DNS 伺服器位址為本機

# 驗證設定
Write-Host "`n正在驗證 IP 設定..." -ForegroundColor Cyan  # 顯示進度訊息
$IPConfig = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4  # 取得 IPv4 位址資訊
$DNS = Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4  # 取得 DNS 伺服器資訊

Write-Host "`n✅ IP 位址設定完成！" -ForegroundColor Green  # 顯示完成訊息
Write-Host "`n目前設定：" -ForegroundColor Cyan  # 顯示設定標題
Write-Host "  IP 位址：$($IPConfig.IPAddress)"  # 顯示已設定的 IP 位址
Write-Host "  子網路遮罩長度：$($IPConfig.PrefixLength)"  # 顯示子網路遮罩長度
Write-Host "  DNS 伺服器：$($DNS.ServerAddresses)"  # 顯示 DNS 伺服器位址
Write-Host ""  # 空行
