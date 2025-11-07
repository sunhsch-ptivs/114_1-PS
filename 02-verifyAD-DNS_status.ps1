# 驗證網域物件
Get-ADDomain | Format-List DNSRoot,NetBIOSName,InfrastructureMaster,DomainMode  # 取得 Active Directory 網域資訊並以清單格式顯示 DNS 根網域、NetBIOS 名稱、基礎結構主機及網域功能等級

# 驗證網域控制站服務可用
nltest /dsgetdc:tcivs.com.tw  # 使用 nltest 工具測試並取得 tcivs.com.tw 網域的網域控制站資訊，確認網域控制站服務是否正常運作

# 驗證 DNS 區域是否建立（正向查詢區）
Get-DnsServerZone  # 列出 DNS 伺服器上所有已建立的 DNS 區域，包括正向查詢區和反向查詢區，以確認 DNS 服務已正確設定

# 顯示 AD DS、DNS 服務狀態
Get-Service -Name NTDS, DNS | Select-Object Status, Name, DisplayName  # 查詢 NTDS（Active Directory 網域服務）和 DNS 服務的執行狀態、服務名稱及顯示名稱，確認兩個關鍵服務是否正在執行中
