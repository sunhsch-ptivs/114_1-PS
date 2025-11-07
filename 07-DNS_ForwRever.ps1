<# 
  Windows Server 2022 - DNS 一鍵部署
  113 年工科技藝競賽 電腦修護第一站（DNS 正反解 + 主機紀錄）
  
  內容包含：
   - 安裝 DNS Server 角色
   - 建立 Forward Lookup Zone（tcivs.com.tw）
   - 建立 Reverse Lookup Zone（172.16.xx.0/24）
   - 新增 Branch-xx / Business-xx / HR-xx / Customer-xx / www / linux 主機記錄
   - 自動新增 PTR
#>

[CmdletBinding(SupportsShouldProcess)]  # 啟用 Cmdlet 繫結，支援 -WhatIf 和 -Confirm 參數以進行模擬執行和確認
param(  # 定義腳本參數區塊
    [Parameter()] [string] $DomainFqdn = "tcivs.com.tw",  # 網域的完整網域名稱（FQDN），預設值為 tcivs.com.tw
    [Parameter()] [string] $SitePrefix = "172.16",       # 固定題目格式  # IP 位址的前兩個八位元組，固定為 172.16
    [Parameter()] [string] $XX = "01",                   # 崗位編號  # 崗位編號，用於組成完整的 IP 位址範圍
    [Parameter()] [string] $BranchName   = "Branch-01",  # Branch 主機的名稱，預設為 Branch-01
    [Parameter()] [string] $BusinessName = "Business-01",  # Business 主機的名稱，預設為 Business-01
    [Parameter()] [string] $HRName       = "HR-01",  # HR 主機的名稱，預設為 HR-01
    [Parameter()] [string] $CustomerName = "Customer-01"  # Customer 主機的名稱，預設為 Customer-01
)

### ------------------------------
### Step 1. 計算 IP 與 Zone
### ------------------------------
$Net24 = "$SitePrefix.$XX"          # ex: 172.16.01 → 172.16.1  # 組合網路位址的前三個八位元組（例如：172.16.01）
$Net24 = $Net24.Replace(".0", ".")  # 修正格式 (01→1)  # 移除前導零，將 .01 修正為 .1

$BranchIP   = "$Net24.254"   # Branch-xx  # 設定 Branch 主機的 IP 位址為網段的 .254（例如：172.16.1.254）
$BusinessIP = "$Net24.100"   # Fedora Business-xx  # 設定 Business 主機（Fedora）的 IP 位址為網段的 .100
$HRIP       = "$Net24.200"   # HR-xx  # 設定 HR 主機的 IP 位址為網段的 .200
$CustomerIP = "$Net24.50"    # Customer-xx (WAN 給定示例，不會在本網段)  # 設定 Customer 主機的 IP 位址為網段的 .50
$WWWIP      = $BranchIP      # 題目：網站架在 Branch-xx  # 設定 www 主機記錄指向 Branch 主機的 IP 位址
$LinuxIP    = $BusinessIP    # 題目：linux = Business-xx  # 設定 linux 主機記錄指向 Business 主機的 IP 位址

$ForwardZone = $DomainFqdn  # 設定正向查詢區名稱為網域 FQDN（tcivs.com.tw）
$ReverseZone = "$XX.16.172.in-addr.arpa"   # ex: 1.16.172.in-addr.arpa  # 設定反向查詢區名稱，格式為倒序的 IP 加上 in-addr.arpa（例如：1.16.172.in-addr.arpa）

Write-Host "=== DNS Zone ===" -ForegroundColor Cyan  # 以青色顯示 DNS 區域資訊標題
Write-Host " Forward Zone : $ForwardZone"  # 顯示正向查詢區名稱
Write-Host " Reverse Zone : $ReverseZone"  # 顯示反向查詢區名稱
Write-Host " Branch-xx IP : $BranchIP"  # 顯示 Branch 主機的 IP 位址
Write-Host " Business-xx IP : $BusinessIP"  # 顯示 Business 主機的 IP 位址
Write-Host " HR-xx IP      : $HRIP"  # 顯示 HR 主機的 IP 位址
Write-Host "================`n"  # 顯示分隔線並換行

### ------------------------------
### Step 2. 安裝 DNS Server 角色
### ------------------------------
Write-Host "=== Step 2. 安裝 DNS Server 角色 ===" -ForegroundColor Cyan  # 以青色顯示步驟 2 標題
Install-WindowsFeature DNS -IncludeManagementTools | Out-Null  # 安裝 DNS 伺服器角色及其管理工具（如 DNS 管理員），隱藏安裝輸出訊息

### ------------------------------
### Step 3. 建立 Forward Lookup Zone
### ------------------------------
Write-Host "=== Step 3. 建立正向查詢區 (Forward Lookup Zone) ===" -ForegroundColor Cyan  # 以青色顯示步驟 3 標題

if (-not (Get-DnsServerZone -Name $ForwardZone -ErrorAction SilentlyContinue)) {  # 檢查正向查詢區是否已存在，使用 SilentlyContinue 避免錯誤訊息
    Add-DnsServerPrimaryZone -Name $ForwardZone -ReplicationScope "Domain" | Out-Null  # 建立 Active Directory 整合的主要正向查詢區，複寫範圍設定為整個網域，隱藏輸出訊息
} else {  # 若正向查詢區已存在
    Write-Host "Forward Zone $ForwardZone 已存在（略過）"  # 顯示訊息表示該區域已存在，跳過建立步驟
}

### ------------------------------
### Step 4. 建立 Reverse Lookup Zone
### ------------------------------
Write-Host "=== Step 4. 建立反向查詢區 (Reverse Lookup Zone - /24) ===" -ForegroundColor Cyan  # 以青色顯示步驟 4 標題

$NetworkID = "$Net24.0/24"  # 定義網路 ID，格式為 CIDR 表示法（例如：172.16.1.0/24），代表一個 C 類網段

if (-not (Get-DnsServerZone -Name $ReverseZone -ErrorAction SilentlyContinue)) {  # 檢查反向查詢區是否已存在
    Add-DnsServerPrimaryZone -NetworkId $NetworkID -ZoneName $ReverseZone -ReplicationScope "Domain" | Out-Null  # 建立 Active Directory 整合的主要反向查詢區，用於 IP 位址到主機名稱的反向解析，隱藏輸出訊息
} else {  # 若反向查詢區已存在
    Write-Host "Reverse Zone $ReverseZone 已存在（略過）"  # 顯示訊息表示該區域已存在，跳過建立步驟
}

### ------------------------------
### Step 5. 新增主機紀錄（含 PTR）
### ------------------------------
Write-Host "=== Step 5. 新增 A 與 PTR 記錄 ===" -ForegroundColor Cyan  # 以青色顯示步驟 5 標題

function Add-A-and-PTR($host, $ip){  # 定義函式 Add-A-and-PTR，接受主機名稱和 IP 位址作為參數
    Write-Host "新增 $host  →  $ip"  # 顯示正在新增的主機記錄資訊
    # A Record
    Remove-DnsServerResourceRecord -ZoneName $ForwardZone -RRType A -Name $host -Force -ErrorAction SilentlyContinue  # 先移除可能已存在的 A 記錄，避免重複，使用 Force 強制執行，SilentlyContinue 忽略錯誤
    Add-DnsServerResourceRecordA -Name $host -ZoneName $ForwardZone -IPv4Address $ip -AllowUpdateAny -TimeToLive 00:05:00  # 新增 A 記錄（主機名稱到 IP 位址的對應），允許任何更新，TTL 設定為 5 分鐘

    # PTR Record
    $last = $ip.Split(".")[-1]  # 取得 IP 位址的最後一個八位元組（主機部分），用於建立 PTR 記錄名稱
    Remove-DnsServerResourceRecord -ZoneName $ReverseZone -RRType PTR -Name $last -Force -ErrorAction SilentlyContinue  # 先移除可能已存在的 PTR 記錄
    Add-DnsServerResourceRecordPtr -ZoneName $ReverseZone -Name $last -PtrDomainName "$host.$ForwardZone"  # 新增 PTR 記錄（IP 位址到主機名稱的反向對應），完整主機名稱格式為 主機名.網域名
}

# 題目要求的主機紀錄
Add-A-and-PTR -host $BranchName   -ip $BranchIP  # 新增 Branch 主機的 A 和 PTR 記錄
Add-A-and-PTR -host $BusinessName -ip $BusinessIP  # 新增 Business 主機的 A 和 PTR 記錄
Add-A-and-PTR -host $HRName       -ip $HRIP  # 新增 HR 主機的 A 和 PTR 記錄
Add-A-and-PTR -host "www"         -ip $WWWIP  # 新增 www 主機（網站）的 A 和 PTR 記錄，指向 Branch 主機
Add-A-and-PTR -host "linux"       -ip $LinuxIP  # 新增 linux 主機的 A 和 PTR 記錄，指向 Business 主機

# Customer-xx → 不在同一網段，不加入反解
Write-Host "新增 Customer-xx A 記錄（無 PTR，因不在此 /24）"
Remove-DnsServerResourceRecord -ZoneName $ForwardZone -RRType A -Name $CustomerName -Force -ErrorAction SilentlyContinue
Add-DnsServerResourceRecordA -Name $CustomerName -ZoneName $ForwardZone -IPv4Address $CustomerIP -AllowUpdateAny

Write-Host "`n✅ DNS 安裝與所有主機紀錄設定完成！" -ForegroundColor Green
