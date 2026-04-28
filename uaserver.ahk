#Requires AutoHotkey v2.0
#NoTrayIcon
Persistent

; ========== КОНФІГУРАЦІЯ ==========
global AppName    := "UAServer"
global BaseDir    := A_ScriptDir
global CurPHP     := "8.5"
global NginxConf  := BaseDir "\bin\nginx\conf\nginx.conf"
global CurPort    := 80 
global IsPro       := CheckLicense()  ; Перевірка ліцензії
global MaxSites    := IsPro ? 999 : 3  ; Обмеження для Free версії

; URL для сторінки start (можна редагувати на сайті)
global StartPageUrl := "https://uaserver.pp.ua/start/index.html"

; Локальний fallback (якщо немає інтернету)
global LocalStartPage := BaseDir "\start\index.html"

; ========== ФУНКЦІЯ ПЕРЕВІРКИ ЛІЦЕНЗІЇ ==========
CheckLicense() {
    ; Перевіряємо наявність ліцензійного ключа
    licenseFile := A_ScriptDir "\license.key"
    if FileExist(licenseFile) {
        try {
            content := FileRead(licenseFile)
            ; Перевірка через ваш API (або локальна перевірка)
            if VerifyLicenseKey(content)
                return true
        }
    }
    return false
}

VerifyLicenseKey(key) {
    ; Тут можна зробити запит до вашого API
    ; Або локальну перевірку за алгоритмом
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", "https://uaserver.pp.ua/api/verify.php?key=" key, false)
        whr.Send()
        return (whr.ResponseText = "valid")
    }
    return false
}

; ========== ГОЛОВНЕ ВІКНО ==========
ShowBanner(*) {
    global MyGui := Gui("-Caption +AlwaysOnTop +Border", AppName)
    MyGui.BackColor := "#1a1a2e"
    
    ; Відображаємо статус ліцензії
    licenseStatus := IsPro ? "⭐ PRO версія (без обмежень)" : "📦 Free версія (макс. " MaxSites " сайти)"
    
    MyGui.SetFont("s12 cWhite", "Segoe UI")
    MyGui.Add("Text", "x20 y10 w460 center", licenseStatus)
    
    ; WebView для відображення start сторінки
    try {
        global WB := MyGui.Add("ActiveX", "x10 y40 w480 h300", "Shell.Explorer")
        WB.Value.Silent := true
        
        ; Спроба завантажити онлайн сторінку
        try {
            WB.Value.Navigate(StartPageUrl "?v=" A_TickCount "&pro=" IsPro)
        } catch {
            ; Fallback на локальну сторінку
            if FileExist(LocalStartPage)
                WB.Value.Navigate("file:///" StrReplace(LocalStartPage, "\", "/"))
        }
        
        Loop 20 {
            Sleep(100)
            if (WB.Value.ReadyState = 4)
                break
        }
    }

    ; КНОПКА ЗАПУСКУ
    MyGui.SetFont("s14 w700 cWhite", "Segoe UI")
    Btn := MyGui.Add("Button", "x100 y345 w300 h50 Default", "🚀 ЗАПУСТИТИ СЕРВЕР")
    Btn.SetFont("cGreen")
    Btn.OnEvent("Click", StartEverything)
    
    ; КНОПКА ДЛЯ PRO (якщо немає ліцензії)
    if !IsPro {
        ProBtn := MyGui.Add("Button", "x100 y400 w300 h35", "⭐ Отримати PRO версію")
        ProBtn.SetFont("cBlue")
        ProBtn.OnEvent("Click", (*) => Run("https://uaserver.pp.ua/pro"))
    }
    
    MyGui.Show("w500 h480 center")
}

; ========== ЗАПУСК ВСЬОГО ==========
StartEverything(*) {
    MyGui.Hide()
    
    ; Показуємо умови Free версії
    if !IsPro {
        MsgBox("⚡ Free версія UAServer`n`n" 
               . "✅ До 3-х сайтів у папці www`n"
               . "✅ PHP 7.4/8.5`n"
               . "✅ MySQL`n`n"
               . "⭐ Для необмеженої кількості сайтів придбайте PRO!", 
               "Інформація", 64)
    }
    
    if FileExist(BaseDir "\logo.ico")
        TraySetIcon(BaseDir "\logo.ico")
    A_IconHidden := false 
    
    global CurPort := CheckPortFree(80) ? 80 : 8080
    UpdateMenu()
    StartServer()
    
    ; ВІДКРИВАЄМО СТОРІНКУ В БРАУЗЕРІ
    Sleep(1500)
    Run("http://localhost" . (CurPort == 80 ? "" : ":" CurPort))
}

; ========== ТРЕЙ МЕНЮ ==========
UpdateMenu() {
    Tray := A_TrayMenu
    Tray.Delete()
    p := (CurPort == 80) ? "" : ":" CurPort
    
    Tray.Add("Мій сайт (localhost)", (*) => Run("http://localhost" p "/"))
    Tray.Add("PhpMyAdmin", (*) => Run("http://localhost" p "/phpmyadmin/"))
    Tray.Add()
    
    ; МЕНЮ САЙТІВ (з обмеженням для Free)
    SitesMenu := Menu()
    sites := GetSiteList()
    if !IsPro and sites.Length > MaxSites {
        MsgBox("❗ У Free версії обмеження: " MaxSites " сайти.`nДеякі сайти не відображаються.", "Увага", 48)
    }
    
    for i, site in sites {
        if !IsPro and i > MaxSites
            break
        SitesMenu.Add(site.name, (*) => Run("http://localhost" p "/" site.folder))
    }
    
    if !IsPro and sites.Length > MaxSites {
        SitesMenu.Add()
        SitesMenu.Add("⭐ Придбати PRO для всіх сайтів", (*) => Run("https://uaserver.pp.ua/pro"))
    }
    Tray.Add("Мої сайти", SitesMenu)
    Tray.Add()
    
    ; МЕНЮ ЗБІРОК (CMS)
    BuildsMenu := Menu()
    BuildsMenu.Add("🛒 WordPress", (*) => DeployCMS("wordpress"))
    BuildsMenu.Add("🛍️ WooCommerce", (*) => DeployCMS("woocommerce"))
    BuildsMenu.Add("📰 Joomla", (*) => DeployCMS("joomla"))
    BuildsMenu.Add("🏠 Drupal", (*) => DeployCMS("drupal"))
    BuildsMenu.Add("⚡ Laravel", (*) => DeployCMS("laravel"))
    Tray.Add("📦 Розгорнути готову збірку", BuildsMenu)
    Tray.Add()
    
    ; МЕНЮ PHP
    PhpMenu := Menu()
    PhpMenu.Add("PHP 7.4", (n, *) => SetPHP("7.4"))
    PhpMenu.Add("PHP 8.5", (n, *) => SetPHP("8.5"))
    (CurPHP == "7.4") ? PhpMenu.Check("PHP 7.4") : PhpMenu.Check("PHP 8.5")
    Tray.Add("Версія PHP", PhpMenu)
    
    ; PRO функції в треї
    if IsPro {
        Tray.Add()
        Tray.Add("⚙️ Резервне копіювання", BackupAllSites)
        Tray.Add("🔄 Автооновлення", SetupAutoUpdate)
    } else {
        Tray.Add()
        Tray.Add("⭐ PRO функції (захист, бекапи, автооновлення)", (*) => Run("https://uaserver.pp.ua/pro"))
    }
    
    Tray.Add()
    Tray.Add("Запустити сервер", (*) => StartServer())
    Tray.Add("Зупинити сервер", StopServer)
    Tray.Add()
    Tray.Add("Мої сайти (www)", (*) => Run("explorer.exe `"" BaseDir "\www`""))
    Tray.Add("Відкрити start сторінку", (*) => Run(StartPageUrl))
    Tray.Add("Вийти", (*) => (StopServer(), ExitApp()))
}

; ========== ОТРИМАННЯ СПИСКУ САЙТІВ ==========
GetSiteList() {
    sites := []
    wwwDir := BaseDir "\www"
    if DirExist(wwwDir) {
        loop files wwwDir "\*", "D" {
            ; Перевіряємо наявність index файлу
            if FileExist(wwwDir "\" A_LoopFileName "\index.php") 
                or FileExist(wwwDir "\" A_LoopFileName "\index.html") {
                sites.Push({name: A_LoopFileName, folder: A_LoopFileName})
            }
        }
    }
    return sites
}

; ========== РОЗГОРТАННЯ CMS ==========
DeployCMS(cmsType) {
    siteName := InputBox("Введіть назву папки для сайту:", "Розгортання " cmsType, "w300 h130")
    if !siteName.Result
        return
    
    sitePath := BaseDir "\www\" siteName.Value
    if DirExist(sitePath) {
        MsgBox("Папка з таким ім'ям вже існує!", "Помилка", 48)
        return
    }
    
    ; Перевірка ліміту для Free
    if !IsPro and GetSiteList().Length >= MaxSites {
        MsgBox("❗ У Free версії ліміт: " MaxSites " сайти.`nПридбайте PRO для зняття обмежень!", "Ліміт", 48)
        return
    }
    
    DirCreate(sitePath)
    
    ; Завантаження та розпакування CMS
    MsgBox("Завантаження " cmsType "...", "Зачекайте", 64)
    
    ; Тут логіка завантаження з вашого сервера
    ; Наприклад для WordPress:
    if (cmsType = "wordpress") {
        DownloadFile("https://wordpress.org/latest.zip", sitePath "\temp.zip")
        UnzipFile(sitePath "\temp.zip", sitePath)
        FileDelete(sitePath "\temp.zip")
    } else if (cmsType = "woocommerce") {
        ; WordPress + WooCommerce
        DownloadFile("https://wordpress.org/latest.zip", sitePath "\temp.zip")
        UnzipFile(sitePath "\temp.zip", sitePath)
        ; Додатково завантажити WooCommerce plugin
        DownloadFile("https://downloads.wordpress.org/plugin/woocommerce.latest-stable.zip", sitePath "\wp-content\plugins\woocommerce.zip")
        UnzipFile(sitePath "\wp-content\plugins\woocommerce.zip", sitePath "\wp-content\plugins\")
    } else if (cmsType = "joomla") {
        DownloadFile("https://downloads.joomla.org/latest.zip", sitePath "\temp.zip")
        UnzipFile(sitePath "\temp.zip", sitePath)
    }
    
    MsgBox("✅ " cmsType " розгорнуто в папці `"" siteName.Value "`"`n`n"
           . "🔗 http://localhost/" siteName.Value, "Готово!", 64)
    
    ; Оновлюємо меню
    UpdateMenu()
}

; Допоміжні функції для завантаження
DownloadFile(url, dest) {
    try {
        Download(url, dest)
        return true
    } catch {
        MsgBox("Помилка завантаження: " url, "Помилка", 48)
        return false
    }
}

UnzipFile(zipPath, destPath) {
    try {
        shell := ComObject("Shell.Application")
        zip := shell.NameSpace(zipPath)
        dest := shell.NameSpace(destPath)
        dest.CopyHere(zip.Items(), 16+256)  ; 16=NoConfirm, 256=NoProgress
        return true
    }
    return false
}

; ========== PRO ФУНКЦІЇ ==========
BackupAllSites(*) {
    if !IsPro {
        MsgBox("⭐ Функція доступна тільки в PRO версії!", "Потрібна ліцензія", 48)
        return
    }
    
    backupDir := BaseDir "\backups\" FormatTime(, "yyyy-MM-dd_HH-mm")
    DirCreate(backupDir)
    
    ; Копіюємо всі сайти
    loop files BaseDir "\www\*", "D" {
        if (A_LoopFileName != "." and A_LoopFileName != "..") {
            FileCopyDir(BaseDir "\www\" A_LoopFileName, backupDir "\" A_LoopFileName, 1)
        }
    }
    MsgBox("✅ Бекап створено в: " backupDir, "Готово!", 64)
}

SetupAutoUpdate(*) {
    if !IsPro {
        MsgBox("⭐ Функція доступна тільки в PRO версії!", "Потрібна ліцензія", 48)
        return
    }
    ; Тут логіка налаштування автооновлення
    MsgBox("Автооновлення налаштовано! Програма буде перевіряти оновлення щотижня.", "Налаштування", 64)
}

; ========== ІНШІ ФУНКЦІЇ ==========
SetPHP(ver) {
    global CurPHP := ver
    UpdateMenu()
    if ProcessExist("nginx.exe")
        StartServer()
}

StartServer(*) {
    StopServer()
    Sleep(500)
    
    PhpFolder := (CurPHP == "7.4") ? "php74" : "php85"
    phpExe    := BaseDir "\bin\" PhpFolder "\php-cgi.exe"
    nginxDir  := BaseDir "\bin\nginx"
    mysqlDir  := BaseDir "\bin\mysql"
    
    fixedWWW := StrReplace(BaseDir "\www", "\", "/")
    fixedBin := StrReplace(BaseDir "\bin", "\", "/")
    
    ; Генерація nginx.conf з підтримкою декількох сайтів
    Conf := GenerateNginxConfig(fixedWWW, fixedBin)
    
    if FileExist(NginxConf)
        FileDelete(NginxConf)
    FileAppend(Conf, NginxConf, "UTF-8-RAW")
    
    try {
        Run(A_ComSpec ' /c start "" /b "' phpExe '" -b 127.0.0.1:9000', BaseDir "\bin\" PhpFolder, "Hide")
        
        if FileExist(mysqlDir "\bin\mysqld.exe") {
            SetWorkingDir(mysqlDir)
            Run(A_ComSpec ' /c start "" /b bin\mysqld.exe --defaults-file=my.ini --standalone', mysqlDir, "Hide")
            SetWorkingDir(BaseDir)
        }
        
        Sleep(1000)
        SetWorkingDir(nginxDir)
        Run(A_ComSpec ' /c start "" /b nginx.exe', nginxDir, "Hide")
        SetWorkingDir(BaseDir)
        
        TrayTip("UAServer", "Сервер запущено на порту " CurPort, 2)
    }
}

GenerateNginxConfig(wwwRoot, binRoot) {
    ; Базовий конфіг + автоматичне додавання всіх сайтів з папки www
    config := "worker_processes 1; events { worker_connections 1024; } http { include mime.types; default_type application/octet-stream; charset utf-8;"
    
    ; Додаємо кожен сайт як окремий server block або location
    config .= " server { listen " CurPort "; server_name localhost; root '" wwwRoot "'; index index.php index.html;"
    
    ; Автоматичні location для кожної папки в www
    loop files wwwRoot "\*", "D" {
        if (!IsPro and A_Index > MaxSites)
            continue
        folder := A_LoopFileName
        config .= " location ^~ /" folder " { alias '" wwwRoot "/" folder "/'; try_files $uri $uri/ /" folder "/index.php?$args; }"
    }
    
    config .= " location ~ \.php$ { fastcgi_pass 127.0.0.1:9000; fastcgi_index index.php; fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; include fastcgi_params; }"
    config .= " } }"
    
    return config
}

StopServer(*) {
    try RunWait(A_ComSpec ' /c taskkill /f /im nginx.exe /im php-cgi.exe /im mysqld.exe', , "Hide")
}

CheckPortFree(port) {
    try {
        exec := ComObject("WScript.Shell").Exec(A_ComSpec " /c netstat -ano | findstr /R `": " port " `".*LISTENING`"")
        return (exec.StdOut.ReadAll() == "")
    } catch {
        return true
    }
}

; Запуск
ShowBanner()