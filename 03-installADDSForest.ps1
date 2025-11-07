#安裝 AD CS 角色並建立「企業根 CA」

# ===== 變數 =====
$DomainFqdn     = "tcivs.com.tw"  # 定義網域的完整網域名稱（FQDN）
$CaCommonName   = "TCIVS-ROOT-CA"       # 企業根 CA 顯示名稱  # 憑證授權單位的通用名稱，會顯示在所有核發的憑證中
$KeyLength      = 2048  # 設定 RSA 金鑰長度為 2048 位元，這是目前廣泛使用的安全金鑰長度
$HashAlgorithm  = "SHA256"  # 指定雜湊演算法為 SHA256，用於數位簽章以確保憑證的完整性和真實性
$ValidityYears  = 10                     # 根憑證有效年限（示例 10 年）  # 設定根憑證的有效期限為 10 年
$RootCerPath    = "C:\PKI\TCIVS-ROOT-CA.cer"   # 匯出根憑證供發佈/備份  # 定義根憑證的匯出路徑，供後續發佈到 Active Directory 或備份使用
$CRLPath_Local  = "C:\PKI\CRL"                 # CRL 輸出目錄（本機檔案）  # 定義憑證撤銷清單（Certificate Revocation List）的本機儲存目錄
$GpoName        = "TCIVS-Cert-AutoEnrollment"  # 啟用電腦端自動註冊之 GPO 名稱  # 群組原則物件名稱，用於設定網域電腦自動註冊憑證
$WebTemplate    = "WebServer"                  # 內建網站伺服器範本（預設存在）  # 指定使用內建的網站伺服器憑證範本，用於核發 SSL/TLS 憑證


# 建立必要目錄
New-Item -ItemType Directory -Path (Split-Path $RootCerPath) -Force | Out-Null  # 建立根憑證儲存目錄（C:\PKI），-Force 參數會自動覆蓋已存在的目錄，Out-Null 隱藏輸出訊息
New-Item -ItemType Directory -Path $CRLPath_Local -Force | Out-Null  # 建立 CRL 儲存目錄（C:\PKI\CRL），用於存放憑證撤銷清單檔案

# 安裝 AD CS 角色（含管理工具）
Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools  # 安裝 Active Directory 憑證服務（AD CS）角色及其圖形化管理工具，如憑證授權單位管理主控台

# 設定 DSRM 密碼
$DSRM = Read-Host "請輸入 DSRM 安全模式密碼" -AsSecureString  # 提示使用者輸入目錄服務還原模式（Directory Services Restore Mode）的管理員密碼，並以安全字串格式儲存

# 建立「企業根 CA」，同時建立金鑰與 CA 資料庫
Install-AdcsCertificationAuthority `  # 執行 AD CS 憑證授權單位安裝與設定命令
  -CAType EnterpriseRootCA `  # 指定 CA 類型為企業根 CA，整合於 Active Directory 中，可自動核發憑證給網域成員
  -CACommonName $CaCommonName `  # 設定 CA 的通用名稱（使用前面定義的變數 TCIVS-ROOT-CA）
  -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `  # 指定密碼編譯服務提供者，使用 Microsoft 軟體金鑰儲存提供者來儲存私密金鑰
  -KeyLength $KeyLength `  # 設定 CA 金鑰長度為 2048 位元（使用前面定義的變數）
  -HashAlgorithm $HashAlgorithm `  # 設定雜湊演算法為 SHA256（使用前面定義的變數）
  -ValidityPeriod Years `  # 指定有效期限單位為「年」
  -ValidityPeriodUnits $ValidityYears `  # 設定有效期限為 10 年（使用前面定義的變數）
  -Force  # 強制執行安裝，不會出現確認提示訊息

# 啟動 AD CS 服務
Start-Service CertSvc  # 啟動憑證服務（Certificate Services），使 CA 開始提供憑證核發和管理功能
