#驗證清單（評分前自檢）
# CA 與服務狀態
Get-Service CertSvc  # 查詢憑證服務（CertSvc）的執行狀態，確認 CA 服務是否正在執行

# CA 資訊
certutil -ca.info  # 使用 certutil 工具顯示憑證授權單位的詳細資訊，包括 CA 名稱、類型、憑證等資訊

# 目錄內發佈之根憑證/NTAuth 狀態
certutil -enterprise -viewstore root  # 以企業模式檢視 Active Directory 中已發佈的受信任根憑證，確認根 CA 憑證是否已正確發佈
certutil -enterprise -viewstore ntauth  # 以企業模式檢視 Active Directory 中的 NTAuth 憑證存放區，用於智慧卡和其他驗證機制

# 範本與 CA 對應
certutil -catemplates  # 列出 CA 上已啟用的所有憑證範本，確認哪些範本可用於核發憑證

# 於客戶端（網域電腦）檢查是否已信任根 CA
certutil -store -enterprise root | findstr /C:"TCIVS-ROOT-CA"  # 在企業根憑證存放區中搜尋 TCIVS-ROOT-CA，確認網域電腦是否已透過群組原則自動信任此根 CA
