# ===============================
#  AD CS Enterprise Root CA 一鍵部署
#  Windows Server 2022 — Branch-01
#  Domain: tcivs.com.tw
# ===============================

# ---- 變數 ----
$DomainFqdn     = "tcivs.com.tw"  # 網域的完整網域名稱（FQDN）
$CaCommonName   = "TCIVS-ROOT-CA"  # 憑證授權單位的通用名稱
$KeyLength      = 2048  # RSA 金鑰長度設定為 2048 位元
$HashAlgorithm  = "SHA256"  # 使用 SHA256 雜湊演算法進行數位簽章
$ValidityYears  = 10  # 根憑證有效期限設定為 10 年
$RootCerPath    = "C:\PKI\TCIVS-ROOT-CA.cer"  # 根憑證的匯出檔案路徑
$CRLPath        = "C:\PKI\CRL"  # 憑證撤銷清單（CRL）的儲存目錄路徑
$GpoName        = "TCIVS-Cert-AutoEnrollment"  # 用於自動註冊憑證的群組原則物件名稱
$WebTemplate    = "WebServer"  # 網站伺服器憑證範本名稱

# ---- 建立必要目錄 ----
New-Item -ItemType Directory -Path (Split-Path $RootCerPath) -Force | Out-Null  # 建立 PKI 根目錄（C:\PKI），Out-Null 隱藏建立訊息
New-Item -ItemType Directory -Path $CRLPath -Force | Out-Null  # 建立 CRL 子目錄（C:\PKI\CRL）

# ---- 安裝 AD CS 角色 ----
Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools  # 安裝 Active Directory 憑證服務角色及管理工具

# ---- 建立企業根 CA ----
$DSRM = Read-Host "請輸入 DSRM 密碼" -AsSecureString  # 提示輸入目錄服務還原模式密碼並以安全字串儲存

Install-AdcsCertificationAuthority `  # 執行憑證授權單位安裝命令
  -CAType EnterpriseRootCA `  # 設定為企業根 CA 類型，整合於 Active Directory 環境
  -CACommonName $CaCommonName `  # 指定 CA 的通用名稱
  -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `  # 使用 Microsoft 軟體金鑰儲存提供者
  -KeyLength $KeyLength `  # 設定金鑰長度為 2048 位元
  -HashAlgorithm $HashAlgorithm `  # 設定雜湊演算法為 SHA256
  -ValidityPeriod Years `  # 有效期限單位為「年」
  -ValidityPeriodUnits $ValidityYears `  # 有效期限為 10 年
  -Force  # 強制執行，不顯示確認提示

Restart-Service CertSvc  # 重新啟動憑證服務以套用設定

# ---- 匯出根憑證並發佈到 AD ----
$root = Get-ChildItem -Path Cert:\LocalMachine\CA |  # 從本機電腦的 CA 憑證存放區中取得所有憑證
        Where-Object { $_.Subject -like "*CN=$CaCommonName*" } |  # 篩選出主體包含指定 CA 名稱的憑證
        Select-Object -First 1  # 選取第一個符合的憑證（根憑證）

Export-Certificate -Cert $root -FilePath $RootCerPath | Out-Null  # 將根憑證匯出為 .cer 檔案，隱藏匯出訊息

certutil -dspublish -f $RootCerPath RootCA  # 將根憑證發佈到 Active Directory 的 RootCA 容器中
certutil -dspublish -f $RootCerPath NTAuthCA  # 將根憑證發佈到 Active Directory 的 NTAuthCA 容器中，用於智慧卡驗證

# ---- 設定 CRL/AIA 發佈（使用 AD 預設為主）----
certutil -setreg CA\CRLPeriodUnits 1  # 設定 CRL 發佈週期單位數為 1
certutil -setreg CA\CRLPeriod "Weeks"  # 設定 CRL 發佈週期為「週」，即每週更新一次 CRL
certutil -setreg CA\CRLPublicationURLs "1:%WINDIR%\system32\CertSrv\CertEnroll\%3%8%9.crl|2:ldap:///CN=%7,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10"  # 設定 CRL 發佈位置，包括本機檔案系統和 LDAP（Active Directory）路徑

certutil -setreg CA\CACertPublicationURLs "1:%WINDIR%\system32\CertSrv\CertEnroll\%1_%3%4.crt|2:ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11"  # 設定 CA 憑證（AIA）發佈位置，用於憑證鏈驗證

Restart-Service CertSvc  # 重新啟動憑證服務以套用 CRL 和 AIA 設定

# ---- CA 啟用 WebServer 範本 ----
certutil -setcatemplates +$WebTemplate  # 在 CA 上啟用 WebServer 憑證範本，允許核發網站伺服器憑證

# ---- WebServer Template 加入 "Domain Computers" Enroll/Autoenroll ----
$rootDse   = [ADSI]"LDAP://RootDSE"  # 連線到 LDAP RootDSE 以取得 Active Directory 根目錄資訊
$configNC  = $rootDse.configurationNamingContext  # 取得設定命名內容（Configuration Naming Context）的 DN
$template  = [ADSI]("LDAP://CN=$WebTemplate,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC")  # 連線到 WebServer 憑證範本的 LDAP 路徑

$domComputers = New-Object System.Security.Principal.NTAccount("Domain Computers")  # 建立網域電腦群組的 NT 帳戶物件
$domComputersSid = $domComputers.Translate([System.Security.Principal.SecurityIdentifier])  # 將 NT 帳戶轉換為安全識別碼（SID）

$ENROLL     = [Guid]"0e8a5346-9e87-4a0d-8c9a-62b731e4c2a9"  # 定義「註冊」權限的 GUID
$AUTOENROLL = [Guid]"a05b8cc2-17bc-4802-a710-e7c15ab866a2"  # 定義「自動註冊」權限的 GUID
$adRights   = [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight  # 指定 Active Directory 權限類型為擴充權限
$allow      = [System.Security.AccessControl.AccessControlType]::Allow  # 設定存取控制類型為「允許」

$ace1 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($domComputersSid, $adRights, $allow, $ENROLL)  # 建立允許網域電腦群組擁有「註冊」權限的存取控制項目
$ace2 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($domComputersSid, $adRights, $allow, $AUTOENROLL)  # 建立允許網域電腦群組擁有「自動註冊」權限的存取控制項目

$sd = $template.ObjectSecurity  # 取得憑證範本的安全描述元
$sd.AddAccessRule($ace1) | Out-Null  # 將「註冊」權限的 ACE 加入安全描述元
$sd.AddAccessRule($ace2) | Out-Null  # 將「自動註冊」權限的 ACE 加入安全描述元
$template.ObjectSecurity = $sd  # 更新憑證範本的安全描述元
$template.CommitChanges()  # 提交變更到 Active Directory

# ---- 啟用 AutoEnrollment GPO ----
Import-Module GroupPolicy  # 匯入群組原則管理模組

if (-not (Get-GPO -Name $GpoName -ErrorAction SilentlyContinue)) {  # 檢查群組原則物件是否已存在，若不存在則建立
  New-GPO -Name $GpoName | Out-Null  # 建立新的群組原則物件並隱藏輸出
}
New-GPLink -Name $GpoName -Target ("DC=" + $DomainFqdn.Replace(".",",DC="))  # 將群組原則物件連結到網域的根目錄（例如：DC=tcivs,DC=com,DC=tw）

Set-GPRegistryValue -Name $GpoName `  # 設定群組原則的登錄值
  -Key "HKLM\Software\Policies\Microsoft\Cryptography\AutoEnrollment" `  # 指定登錄機碼路徑，用於設定自動註冊原則
  -ValueName "AEPolicy" -Type DWord -Value 7  # 設定 AEPolicy 值為 7（二進位：111），啟用憑證的自動註冊、更新和移除功能

gpupdate /force  # 強制立即更新群組原則，使設定生效

Write-Host "`n✅ AD CS 企業根 CA 已成功部署！"  # 顯示部署完成訊息
