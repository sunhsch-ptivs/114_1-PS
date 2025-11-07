# 1) 參數（可依需要調整 NetBIOS 名稱；不填時會自動推導）
$DomainName       = "tcivs.com.tw"  # 定義網域的完整名稱（FQDN），此處設定為 tcivs.com.tw
$DomainNetBIOS    = "TCIVS"  # 定義 NetBIOS 網域名稱，用於舊版 Windows 相容性，若省略系統會自動從 DomainName 推導
$SafeModePassword = Read-Host "輸入 DSRM 安全模式密碼" -AsSecureString  # 提示使用者輸入目錄服務還原模式（DSRM）的管理員密碼，並以安全字串格式儲存

# 2) 安裝 AD DS 角色與管理工具
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools  # 安裝 Active Directory 網域服務角色及其管理工具（如 Active Directory 使用者和電腦）

# 3) 新建樹系與網域（同時安裝整合 DNS）
#    備註：未指定 -NoRebootOnCompletion 時，安裝完成後會自動重新開機
Install-ADDSForest `  # 執行 Active Directory 網域服務樹系安裝命令
  -DomainName $DomainName `  # 指定要建立的網域名稱（使用前面定義的變數）
  -DomainNetbiosName $DomainNetBIOS `  # 指定 NetBIOS 網域名稱（使用前面定義的變數）
  -InstallDNS `  # 同時安裝並設定 DNS 伺服器服務，Active Directory 需要 DNS 才能正常運作
  -SafeModeAdministratorPassword $SafeModePassword `  # 設定目錄服務還原模式的管理員密碼（使用前面輸入的安全字串）
  -Force  # 強制執行安裝，不會出現確認提示訊息，安裝完成後系統會自動重新啟動
