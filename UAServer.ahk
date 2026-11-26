#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent()

; ============================================================
; UAServer Free 8.5.1
; Основа: UAServer Free 8.5
; Виправлено керування MariaDB / MySQL
; Портативний локальний сервер
; ============================================================

global AppName := "UAServer Free"
global AppVersion := "8.5.1"
global BaseDir := A_ScriptDir

global CurPort := 80
global PhpPort := 9000
global MysqlPort := 3306
global CurPHP := "8.5"
global Language := "uk"

global AvailableLanguages := [
    {code: "uk", name: "Українська"},
    {code: "en", name: "English"}
]

global NginxDir := BaseDir "\bin\nginx"
global PhpDir := BaseDir "\bin\php85"
global MysqlDir := BaseDir "\bin\mysql"
global PhpMyAdminDir := BaseDir "\bin\phpmyadmin"

global WwwDir := BaseDir "\www"
global TmpDir := BaseDir "\tmp"
global LogsDir := BaseDir "\logs"
global HomeDir := BaseDir "\www\_uaserver-home"

global StartDir := BaseDir "\start"
global StartPage := StartDir "\index.html"
global StartCache := StartDir "\server-content.html"

global NginxExe := NginxDir "\nginx.exe"
global PhpExe := PhpDir "\php-cgi.exe"
global MysqlExe := MysqlDir "\bin\mysqld.exe"
global MysqlAdminExe := MysqlDir "\bin\mysqladmin.exe"
global MysqlClientExe := MysqlDir "\bin\mysql.exe"

global NginxConf := NginxDir "\conf\nginx.conf"
global PhpIni := PhpDir "\php.ini"
global MysqlIni := MysqlDir "\my.ini"

global NginxPID := 0
global PhpPID := 0
global MysqlPID := 0
global ServerStarted := false

; ============================================================
; ПЕРЕКЛАД
; ============================================================

L(uk, en) {
    global Language
    return Language = "uk" ? uk : en
}

; ============================================================
; НАЛАШТУВАННЯ
; ============================================================

LoadSettings() {
    global Language, CurPHP, BaseDir, AvailableLanguages

    settingsFile := BaseDir "\settings.ini"
    savedLanguage := IniRead(settingsFile, "General", "Language", "")

    languageFound := false

    for lang in AvailableLanguages {
        if savedLanguage = lang.code {
            Language := savedLanguage
            languageFound := true
            break
        }
    }

    if !languageFound {
        systemLanguage := SubStr(A_Language, 3, 2)
        Language := systemLanguage = "22" ? "uk" : "en"
    }

    savedPHP := IniRead(settingsFile, "General", "PHP", "8.5")

    if savedPHP = "7.4" || savedPHP = "8.5"
        CurPHP := savedPHP
}

SetLanguage(lang) {
    global Language, BaseDir, AvailableLanguages

    languageFound := false

    for item in AvailableLanguages {
        if lang = item.code {
            languageFound := true
            break
        }
    }

    if !languageFound
        return

    Language := lang

    IniWrite(lang, BaseDir "\settings.ini", "General", "Language")

    UpdateMenu()
    BuildStartPage()
}

; ============================================================
; ВИБІР МОВИ
; ============================================================

ShowLanguageSelector(*) {
    global Language, AvailableLanguages

    languageNames := []
    selectedIndex := 1

    for index, lang in AvailableLanguages {
        languageNames.Push(lang.name)

        if lang.code = Language
            selectedIndex := index
    }

    languageGui := Gui(
        "+AlwaysOnTop +ToolWindow",
        L("Вибір мови", "Language selection")
    )

    languageGui.SetFont("s10", "Segoe UI")

    languageGui.AddText(
        "w280",
        L("Оберіть мову інтерфейсу:", "Select interface language:")
    )

    languageList := languageGui.AddListBox("w280 r6", languageNames)
    languageList.Choose(selectedIndex)

    applyButton := languageGui.AddButton("Default w130", L("Застосувати", "Apply"))
    cancelButton := languageGui.AddButton("x+10 w130", L("Скасувати", "Cancel"))

    applyButton.OnEvent(
        "Click",
        (*) => ApplyLanguageSelection(languageList.Value, languageGui)
    )

    cancelButton.OnEvent("Click", (*) => languageGui.Destroy())
    languageGui.OnEvent("Close", (*) => languageGui.Destroy())

    languageGui.Show("AutoSize Center")
}

ApplyLanguageSelection(selectedIndex, languageGui) {
    global AvailableLanguages

    if selectedIndex < 1 || selectedIndex > AvailableLanguages.Length
        return

    SetLanguage(AvailableLanguages[selectedIndex].code)
    languageGui.Destroy()
}

; ============================================================
; ВИБІР PHP
; ============================================================

SetPHP(version) {
    global CurPHP, BaseDir

    if version != "7.4" && version != "8.5"
        return

    CurPHP := version

    IniWrite(version, BaseDir "\settings.ini", "General", "PHP")

    StartServer()
}

; ============================================================
; ШЛЯХИ
; ============================================================

UpdatePaths() {
    global BaseDir, CurPHP
    global NginxDir, PhpDir, MysqlDir, PhpMyAdminDir
    global WwwDir, TmpDir, LogsDir, HomeDir
    global StartDir, StartPage, StartCache
    global NginxExe, PhpExe, MysqlExe, MysqlAdminExe, MysqlClientExe
    global NginxConf, PhpIni, MysqlIni

    NginxDir := BaseDir "\bin\nginx"

    phpFolder := CurPHP = "8.5" ? "php85" : "php74"
    PhpDir := BaseDir "\bin\" phpFolder

    MysqlDir := BaseDir "\bin\mysql"
    PhpMyAdminDir := BaseDir "\bin\phpmyadmin"

    WwwDir := BaseDir "\www"
    TmpDir := BaseDir "\tmp"
    LogsDir := BaseDir "\logs"

    HomeDir := WwwDir "\_uaserver-home"

    StartDir := BaseDir "\start"
    StartPage := StartDir "\index.html"
    StartCache := StartDir "\server-content.html"

    NginxExe := NginxDir "\nginx.exe"
    PhpExe := PhpDir "\php-cgi.exe"

    MysqlExe := MysqlDir "\bin\mysqld.exe"
    MysqlAdminExe := MysqlDir "\bin\mysqladmin.exe"
    MysqlClientExe := MysqlDir "\bin\mysql.exe"

    NginxConf := NginxDir "\conf\nginx.conf"
    PhpIni := PhpDir "\php.ini"
    MysqlIni := MysqlDir "\my.ini"
}

CreateDirs() {
    global TmpDir, LogsDir, WwwDir, HomeDir
    global NginxDir, StartDir

    dirs := [
        TmpDir,
        TmpDir "\session",
        LogsDir,
        WwwDir,
        HomeDir,
        NginxDir "\logs",
        StartDir
    ]

    for dir in dirs {
        if !DirExist(dir)
            DirCreate(dir)
    }
}

NginxPath(path) {
    return StrReplace(path, "\", "/")
}

WriteTextFile(path, content) {
    SplitPath(path, , &parentDir)

    if !DirExist(parentDir)
        DirCreate(parentDir)

    if FileExist(path)
        FileDelete(path)

    FileAppend(content, path, "UTF-8-RAW")
}

; ============================================================
; PHP.INI
; ============================================================

WritePhpConfig() {
    global PhpDir, PhpIni, TmpDir, LogsDir

    if FileExist(PhpIni)
        return true

    extDir := NginxPath(PhpDir "\ext")
    sessionDir := NginxPath(TmpDir "\session")
    errorLog := NginxPath(LogsDir "\php_error.log")

    q := Chr(34)

    conf := "[PHP]`n"
        . "engine = On`n"
        . "short_open_tag = Off`n"
        . "precision = 14`n"
        . "output_buffering = 4096`n"
        . "zlib.output_compression = Off`n"
        . "implicit_flush = Off`n"
        . "serialize_precision = -1`n"
        . "zend.enable_gc = On`n"
        . "expose_php = Off`n"
        . "max_execution_time = 1800`n"
        . "max_input_time = 1800`n"
        . "max_input_vars = 10000`n"
        . "memory_limit = 1024M`n"
        . "error_reporting = E_ALL & ~E_NOTICE & ~E_WARNING & ~E_DEPRECATED & ~E_STRICT`n"
        . "display_errors = Off`n"
        . "display_startup_errors = Off`n"
        . "log_errors = On`n"
        . "error_log = " q errorLog q "`n"
        . "variables_order = GPCS`n"
        . "request_order = GP`n"
        . "post_max_size = 1024M`n"
        . "upload_max_filesize = 1024M`n"
        . "max_file_uploads = 50`n"
        . "file_uploads = On`n"
        . "allow_url_fopen = On`n"
        . "allow_url_include = Off`n"
        . "default_socket_timeout = 1800`n"
        . "cgi.fix_pathinfo = 1`n"
        . "date.timezone = Europe/Kyiv`n"
        . "session.save_handler = files`n"
        . "session.save_path = " q sessionDir q "`n"
        . "session.use_strict_mode = 0`n"
        . "session.use_cookies = 1`n"
        . "session.use_only_cookies = 1`n"
        . "session.name = PHPSESSID`n"
        . "session.auto_start = 0`n"
        . "session.cookie_lifetime = 0`n"
        . "session.cookie_path = /`n"
        . "session.gc_probability = 1`n"
        . "session.gc_divisor = 100`n"
        . "session.gc_maxlifetime = 1440`n"
        . "extension_dir = " q extDir q "`n"
        . "extension=curl`n"
        . "extension=gd`n"
        . "extension=mbstring`n"
        . "extension=openssl`n"
        . "extension=zip`n"
        . "extension=fileinfo`n"
        . "extension=intl`n"
        . "extension=mysqli`n"
        . "extension=pdo_mysql`n"
        . "opcache.enable=1`n"
        . "opcache.memory_consumption=128`n"
        . "opcache.max_accelerated_files=10000`n"
        . "opcache.revalidate_freq=0`n"

    WriteTextFile(PhpIni, conf)

    return true
}

OpenPhpIni(*) {
    global PhpIni, PhpDir

    if !FileExist(PhpIni) {
        if !WritePhpConfig() {
            MsgBox(L("Не вдалося створити php.ini.", "Unable to create php.ini."), "UAServer", "Iconx")
            return
        }
    }

    try {
        Run('notepad.exe "' PhpIni '"', PhpDir)
    } catch as err {
        MsgBox(
            L("Не вдалося відкрити php.ini:`n", "Unable to open php.ini:`n") . err.Message,
            "UAServer",
            "Iconx"
        )
    }
}

; ============================================================
; MYSQL / MARIADB CONFIG
; ============================================================

WriteMysqlConfig() {
    global MysqlDir, MysqlIni, MysqlPort
    global TmpDir, LogsDir

    basePath := NginxPath(MysqlDir)
    dataPath := NginxPath(MysqlDir "\data")
    tempPath := NginxPath(TmpDir)
    logPath := NginxPath(LogsDir "\mysql_error.log")

    q := Chr(34)

    conf := "[client]`n"
        . "port=" MysqlPort "`n"
        . "default-character-set=utf8mb4`n"
        . "`n"
        . "[mysql]`n"
        . "default-character-set=utf8mb4`n"
        . "`n"
        . "[mysqld]`n"
        . "port=" MysqlPort "`n"
        . "basedir=" q basePath q "`n"
        . "datadir=" q dataPath q "`n"
        . "tmpdir=" q tempPath q "`n"
        . "character-set-server=utf8mb4`n"
        . "collation-server=utf8mb4_unicode_ci`n"
        . "max_connections=60`n"
        . "max_allowed_packet=256M`n"
        . "tmp_table_size=64M`n"
        . "max_heap_table_size=64M`n"
        . "default_storage_engine=InnoDB`n"
        . "innodb_buffer_pool_size=256M`n"
        . "innodb_log_buffer_size=16M`n"
        . "innodb_flush_log_at_trx_commit=2`n"
        . "innodb_lock_wait_timeout=50`n"
        . "log_error=" q logPath q "`n"
        . "explicit_defaults_for_timestamp=true`n"
        . "sql_mode=NO_ENGINE_SUBSTITUTION`n"

    WriteTextFile(MysqlIni, conf)
}

; ============================================================
; NGINX CONFIG
; ============================================================

WriteNginxConfig() {
    global NginxDir, WwwDir, LogsDir
    global NginxConf, CurPort, PhpPort, PhpMyAdminDir

    rootPath := NginxPath(WwwDir)
    logsPath := NginxPath(LogsDir)
    mimePath := NginxPath(NginxDir "\conf\mime.types")
    fastcgiPath := NginxPath(NginxDir "\conf\fastcgi_params")
    pmaPath := NginxPath(PhpMyAdminDir)

    q := Chr(34)

    conf := "worker_processes 1;`n"
        . "error_log " q logsPath "/nginx_error.log" q " warn;`n"
        . "`n"
        . "events {`n"
        . "    worker_connections 512;`n"
        . "}`n"
        . "`n"
        . "http {`n"
        . "    include " q mimePath q ";`n"
        . "    default_type application/octet-stream;`n"
        . "    charset utf-8;`n"
        . "    sendfile on;`n"
        . "    keepalive_timeout 30;`n"
        . "    client_max_body_size 1024M;`n"
        . "    client_body_timeout 1800;`n"
        . "    send_timeout 1800;`n"
        . "    access_log " q logsPath "/nginx_access.log" q ";`n"
        . "`n"
        . "    server {`n"
        . "        listen " CurPort ";`n"
        . "        server_name localhost 127.0.0.1;`n"
        . "        root " q rootPath q ";`n"
        . "        index index.php index.html index.htm;`n"
        . "        autoindex on;`n"
        . "`n"
        . "        location = / {`n"
        . "            rewrite ^ /_uaserver-home/index.html last;`n"
        . "        }`n"
        . "`n"
        . "        location = /phpmyadmin {`n"
        . "            return 301 /phpmyadmin/;`n"
        . "        }`n"
        . "`n"
        . "        location /phpmyadmin/ {`n"
        . "            alias " q pmaPath "/" q ";`n"
        . "            index index.php;`n"
        . "        }`n"
        . "`n"
        . "        location ~* ^/phpmyadmin/(.+\.php)$ {`n"
        . "            alias " q pmaPath "/$1" q ";`n"
        . "            fastcgi_pass 127.0.0.1:" PhpPort ";`n"
        . "            fastcgi_index index.php;`n"
        . "            include " q fastcgiPath q ";`n"
        . "            fastcgi_param SCRIPT_FILENAME $request_filename;`n"
        . "            fastcgi_param PHP_VALUE " q "display_errors=Off" q ";`n"
        . "            fastcgi_read_timeout 1800;`n"
        . "        }`n"
        . "`n"
        . "        location / {`n"
        . "            try_files $uri $uri/ /index.php?$args;`n"
        . "        }`n"
        . "`n"
        . "        location ~ \.php$ {`n"
        . "            try_files $uri =404;`n"
        . "            fastcgi_pass 127.0.0.1:" PhpPort ";`n"
        . "            fastcgi_index index.php;`n"
        . "            include " q fastcgiPath q ";`n"
        . "            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;`n"
        . "            fastcgi_param PHP_VALUE " q "display_errors=Off" q ";`n"
        . "            fastcgi_read_timeout 1800;`n"
        . "            fastcgi_buffers 16 16k;`n"
        . "            fastcgi_buffer_size 32k;`n"
        . "        }`n"
        . "`n"
        . "        location ~ /\. {`n"
        . "            deny all;`n"
        . "        }`n"
        . "    }`n"
        . "}`n"

    WriteTextFile(NginxConf, conf)
}

; ============================================================
; MYSQL: ВИЗНАЧЕННЯ СВОГО ПРОЦЕСУ
; ============================================================

FindLocalMysqlPID() {
    global MysqlExe

    expectedPath := StrLower(StrReplace(MysqlExe, "/", "\"))

    try {
        wmi := ComObjGet("winmgmts:\\.\root\cimv2")

        processes := wmi.ExecQuery(
            "SELECT ProcessId, ExecutablePath FROM Win32_Process WHERE Name='mysqld.exe'"
        )

        for process in processes {
            actualPath := ""

            try actualPath := process.ExecutablePath

            if actualPath = ""
                continue

            actualPath := StrLower(StrReplace(actualPath, "/", "\"))

            if actualPath = expectedPath
                return process.ProcessId
        }
    } catch {
    }

    return 0
}

; ============================================================
; MYSQL: ПЕРЕВІРКА ГОТОВНОСТІ БАЗИ
; ============================================================

MysqlIsReady() {
    global MysqlClientExe, MysqlPort

    if !FileExist(MysqlClientExe)
        return false

    ; --no-defaults виключає автоматичне читання
    ; сторонніх параметрів клієнта.
    ; Root без пароля підтверджений перевіркою користувача.

    command := '"' MysqlClientExe '" --no-defaults --protocol=tcp'
        . ' -u root -h 127.0.0.1 -P ' MysqlPort
        . ' -N -s -e "SELECT 1"'

    try {
        result := RunWait(command, A_ScriptDir, "Hide")
        return result = 0
    } catch {
        return false
    }
}

WaitForMysqlReady(timeoutMs := 20000) {
    startedAt := A_TickCount

    while (A_TickCount - startedAt) < timeoutMs {
        if MysqlIsReady()
            return true

        Sleep(500)
    }

    return false
}

; ============================================================
; HTML: ЕКРАНУВАННЯ
; ============================================================

HtmlEscape(value) {
    value := StrReplace(value, "&", "&amp;")
    value := StrReplace(value, "<", "&lt;")
    value := StrReplace(value, ">", "&gt;")
    value := StrReplace(value, Chr(34), "&quot;")
    value := StrReplace(value, "'", "&#039;")
    return value
}

; ============================================================
; СПИСОК САЙТІВ
; ============================================================

GetSiteList() {
    global WwwDir

    sites := []

    if !DirExist(WwwDir)
        return sites

    loop files WwwDir "\*", "D" {
        folder := A_LoopFileName

        if folder = "_uaserver-home"
            continue

        folderPath := WwwDir "\" folder

        if FileExist(folderPath "\index.php")
            || FileExist(folderPath "\index.html")
            || FileExist(folderPath "\index.htm") {

            sites.Push({
                name: folder,
                folder: folder
            })
        }
    }

    return sites
}

; ============================================================
; КОНТЕНТ САЙТУ UASERVER + КЕШ
; ============================================================

DownloadServerContent() {
    global AppVersion, StartCache

    url := "https://uaserver.pp.ua/server"

    try {
        request := ComObject("WinHttp.WinHttpRequest.5.1")

        request.SetTimeouts(1500, 1500, 3500, 3500)
        request.Open("GET", url, false)

        request.SetRequestHeader(
            "User-Agent",
            "UAServer-Free/" AppVersion
        )

        request.Send()

        if request.Status = 200 {
            page := request.ResponseText
            fragment := ""

            if RegExMatch(page, 'is)<article\b[^>]*>(.*?)</article>', &articleMatch) {
                article := articleMatch[1]

                if RegExMatch(
                    article,
                    'is)<div\b[^>]*class="[^"]*\bentry-content\b[^"]*"[^>]*>(.*)',
                    &contentMatch
                ) {
                    fragment := contentMatch[1]
                } else {
                    fragment := article
                }
            }

            if fragment = "" {
                if RegExMatch(page, 'is)<main\b[^>]*>(.*?)</main>', &mainMatch)
                    fragment := mainMatch[1]
            }

            if fragment != "" {
                fragment := RegExReplace(fragment, "is)<script\b[^>]*>.*?</script>", "")
                fragment := RegExReplace(fragment, "is)<style\b[^>]*>.*?</style>", "")
                fragment := RegExReplace(fragment, "is)<nav\b[^>]*>.*?</nav>", "")
                fragment := RegExReplace(fragment, "is)<header\b[^>]*>.*?</header>", "")
                fragment := RegExReplace(fragment, "is)<footer\b[^>]*>.*?</footer>", "")
                fragment := RegExReplace(fragment, "is)<form\b[^>]*>.*?</form>", "")

                fragment := RegExReplace(
                    fragment,
                    'i)(src|href)="/',
                    '$1="https://uaserver.pp.ua/'
                )

                try WriteTextFile(StartCache, fragment)

                return fragment
            }
        }
    } catch {
    }

    if FileExist(StartCache) {
        try return FileRead(StartCache, "UTF-8")
    }

    return ""
}

; ============================================================
; СТАРТОВА СТОРІНКА
; ============================================================

BuildStartPage() {
    global HomeDir, Language, AppVersion
    global CurPHP, ServerStarted, CurPort
    global StartDir

    pagePath := HomeDir "\index.html"

    remoteContent := DownloadServerContent()

    if remoteContent = "" {
        localStart := StartDir "\index.html"

        if FileExist(localStart) {
            try {
                localHtml := FileRead(localStart, "UTF-8")

                if RegExMatch(localHtml, "is)<body[^>]*>(.*?)</body>", &localMatch)
                    remoteContent := localMatch[1]
                else
                    remoteContent := localHtml
            }
        }
    }

    if remoteContent = "" {
        remoteContent := Language = "uk"
            ? "<h2>Вітаємо в UAServer Free!</h2><p>Локальний сервер працює автономно.</p>"
            : "<h2>Welcome to UAServer Free!</h2><p>The local server works offline.</p>"
    }

    sites := GetSiteList()
    siteHtml := ""

    if sites.Length = 0 {
        siteHtml := Language = "uk"
            ? "<p class='empty'>Поки що немає встановлених сайтів.</p>"
            : "<p class='empty'>No websites installed yet.</p>"
    } else {
        for site in sites {
            safeName := HtmlEscape(site.name)
            safeFolder := UriEncodePath(site.folder)

            siteHtml .= "<a class='site-item' href='/" safeFolder "/'>"
                . "<span class='site-icon'>🌐</span>"
                . "<span>" safeName "</span>"
                . "<span class='site-arrow'>↗</span>"
                . "</a>"
        }
    }

    nginxStatus := L("Працює", "Running")
    phpStatus := L("PHP " CurPHP, "PHP " CurPHP)
    mysqlStatus := L("Працює", "Running")

    statusClass := ServerStarted ? "online" : "offline"

    if !ServerStarted {
        nginxStatus := L("Не запущено", "Stopped")
        phpStatus := L("Не запущено", "Stopped")
        mysqlStatus := L("Не запущено", "Stopped")
    }

    portSuffix := CurPort = 80 ? "" : ":" CurPort

    pageTitle := L("UAServer — локальний сервер", "UAServer — Local Server")
    headerTitle := L("Локальний сервер працює!", "Your local server is running!")
    headerSubtitle := L(
        "Середовище для розробки та тестування сайтів",
        "Your website development and testing environment"
    )

    contentTitle := L("Новини, повідомлення та пропозиції", "News, announcements and offers")
    sitesTitle := L("Мої локальні сайти", "My local websites")

    serverLabel := ServerStarted
        ? L("СЕРВЕР ЗАПУЩЕНО", "SERVER RUNNING")
        : L("СЕРВЕР ЗУПИНЕНО", "SERVER STOPPED")

    html := "<!DOCTYPE html>`n"
        . "<html lang='" Language "'>`n"
        . "<head>`n"
        . "<meta charset='utf-8'>`n"
        . "<meta name='viewport' content='width=device-width,initial-scale=1'>`n"
        . "<title>" pageTitle "</title>`n"
        . "<style>`n"
        . "*{box-sizing:border-box}`n"
        . "body{margin:0;background:#f2f5fa;color:#1e293b;font-family:Segoe UI,Arial,sans-serif}`n"
        . ".top{background:linear-gradient(120deg,#102b4e,#155b91);color:#fff;padding:30px 20px}`n"
        . ".wrap{max-width:1120px;margin:auto}`n"
        . ".brand{display:flex;align-items:center;justify-content:space-between;gap:15px;flex-wrap:wrap}`n"
        . ".brand-name{font-size:22px;font-weight:700;letter-spacing:.3px}`n"
        . ".version{font-size:12px;color:#c7def2}`n"
        . ".badge{font-size:11px;font-weight:700;letter-spacing:1px;padding:8px 13px;border-radius:30px;background:#176b55;color:#fff}`n"
        . ".badge.offline{background:#a33a3a}`n"
        . "h1{font-size:30px;margin:28px 0 8px;font-weight:700}`n"
        . ".subtitle{color:#d2e3f2;font-size:15px;margin:0}`n"
        . ".main{max-width:1120px;margin:25px auto;padding:0 18px}`n"
        . ".grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:15px}`n"
        . ".card{background:#fff;border:1px solid #e4eaf1;border-radius:13px;padding:19px;box-shadow:0 3px 12px rgba(20,45,75,.04)}`n"
        . ".card-head{display:flex;align-items:center;gap:11px;font-weight:700;font-size:15px}`n"
        . ".ico{width:38px;height:38px;display:flex;align-items:center;justify-content:center;border-radius:10px;background:#eaf3fc;font-size:19px}`n"
        . ".state{margin:12px 0 0 49px;color:#16815c;font-size:13px;font-weight:600}`n"
        . ".state.offline{color:#b45353}`n"
        . ".section{margin-top:24px}`n"
        . ".section-title{font-size:19px;font-weight:700;margin:0 0 14px}`n"
        . ".sites{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}`n"
        . ".site-item{display:flex;align-items:center;gap:12px;text-decoration:none;color:#26384c;background:#fff;border:1px solid #e4eaf1;padding:14px;border-radius:10px;transition:.15s}`n"
        . ".site-item:hover{border-color:#4b91c9;background:#f8fbff}`n"
        . ".site-icon{font-size:18px}`n"
        . ".site-arrow{margin-left:auto;color:#3982bd}`n"
        . ".empty{color:#64748b;font-size:14px}`n"
        . ".content{background:#fff;border:1px solid #e4eaf1;border-radius:13px;padding:22px;overflow:hidden;line-height:1.65}`n"
        . ".content img{max-width:100%;height:auto;border-radius:9px}`n"
        . ".content iframe{max-width:100%}`n"
        . ".content a{color:#1769aa}`n"
        . ".content h1,.content h2,.content h3{color:#193c60;margin-top:15px}`n"
        . ".content p{margin:10px 0}`n"
        . ".content table{max-width:100%;border-collapse:collapse}`n"
        . ".content td,.content th{padding:8px;border:1px solid #e2e8f0}`n"
        . ".quick{display:flex;gap:10px;flex-wrap:wrap;margin-top:19px}`n"
        . ".quick a{display:inline-block;padding:11px 16px;background:#1769aa;color:#fff;border-radius:8px;text-decoration:none;font-size:13px;font-weight:600}`n"
        . ".quick a:hover{background:#105486}`n"
        . "footer{text-align:center;color:#8492a5;font-size:12px;padding:28px 15px}`n"
        . "@media(max-width:700px){h1{font-size:24px}.grid{grid-template-columns:1fr}.sites{grid-template-columns:1fr}.top{padding:24px 18px}.content{padding:15px}}`n"
        . "</style>`n"
        . "</head>`n"
        . "<body>`n"
        . "<header class='top'><div class='wrap'>`n"
        . "<div class='brand'>`n"
        . "<div><div class='brand-name'>▣ UAServer Free</div>"
        . "<div class='version'>Version " AppVersion "</div></div>`n"
        . "<div class='badge " statusClass "'>" serverLabel "</div>`n"
        . "</div>`n"
        . "<h1>" headerTitle "</h1>`n"
        . "<p class='subtitle'>" headerSubtitle "</p>`n"
        . "</div></header>`n"
        . "<main class='main'>`n"
        . "<div class='grid'>`n"
        . "<div class='card'><div class='card-head'><span class='ico'>🌐</span>Nginx</div>"
        . "<div class='state " (ServerStarted ? "" : "offline") "'>" nginxStatus "</div></div>`n"
        . "<div class='card'><div class='card-head'><span class='ico'>⚙️</span>" phpStatus "</div>"
        . "<div class='state " (ServerStarted ? "" : "offline") "'>" (ServerStarted ? L("FastCGI активний", "FastCGI active") : L("Зупинено", "Stopped")) "</div></div>`n"
        . "<div class='card'><div class='card-head'><span class='ico'>🗄️</span>MySQL</div>"
        . "<div class='state " (ServerStarted ? "" : "offline") "'>" mysqlStatus "</div></div>`n"
        . "</div>`n"
        . "<div class='quick'>`n"
        . "<a href='/phpmyadmin/'>🗄 phpMyAdmin</a>`n"
        . "<a href='http://localhost" portSuffix "/'>⌂ " L("Головна", "Home") "</a>`n"
        . "</div>`n"
        . "<section class='section'><h2 class='section-title'>" sitesTitle "</h2>`n"
        . "<div class='sites'>" siteHtml "</div></section>`n"
        . "<section class='section'><h2 class='section-title'>" contentTitle "</h2>`n"
        . "<div class='content'>" remoteContent "</div></section>`n"
        . "</main>`n"
        . "<footer>UAServer Free " AppVersion " · " L("Портативний локальний сервер", "Portable local server") "</footer>`n"
        . "</body></html>"

    WriteTextFile(pagePath, html)
}

UriEncodePath(value) {
    return StrReplace(value, " ", "%20")
}

; ============================================================
; ЯРЛИК
; ============================================================

CreateDesktopShortcut() {
    global BaseDir

    shortcutPath := A_Desktop "\UAServer.lnk"
    iconPath := BaseDir "\logo.ico"

    try {
        if A_IsCompiled {
            targetPath := A_ScriptFullPath
            targetArgs := ""

            if !FileExist(iconPath)
                iconPath := A_ScriptFullPath
        } else {
            targetPath := A_AhkPath
            targetArgs := '"' A_ScriptFullPath '"'

            if !FileExist(iconPath)
                iconPath := A_AhkPath
        }

        if FileExist(shortcutPath)
            FileDelete(shortcutPath)

        FileCreateShortcut(
            targetPath,
            shortcutPath,
            BaseDir,
            targetArgs,
            "Запуск UAServer Free",
            iconPath
        )
    } catch {
    }
}

; ============================================================
; ЗАПУСК СЕРВЕРА
; ============================================================

StartServer(*) {
    global NginxExe, PhpExe, MysqlExe
    global NginxDir, PhpDir, MysqlDir
    global NginxConf, PhpIni, MysqlIni
    global NginxPID, PhpPID, MysqlPID
    global ServerStarted, BaseDir
    global PhpMyAdminDir

    ; Спочатку штатно зупиняємо попередній запуск.
    if !StopServer()
        return

    UpdatePaths()
    CreateDirs()

    missing := ""

    if !FileExist(NginxExe)
        missing .= "`n- " NginxExe

    if !FileExist(PhpExe)
        missing .= "`n- " PhpExe

    if !FileExist(MysqlExe)
        missing .= "`n- " MysqlExe

    if !FileExist(PhpMyAdminDir)
        missing .= "`n- " PhpMyAdminDir

    if missing != "" {
        MsgBox(
            L("Не знайдено необхідні файли або папки:`n", "Required files or folders not found:`n")
            . missing . "`n`n"
            . L("Перевір структуру папок UAServer.", "Check the UAServer folder structure."),
            "UAServer",
            "Iconx"
        )
        return
    }

    if !DirExist(MysqlDir "\data") {
        MsgBox(
            L(
                "Не знайдено папку баз даних:`n" MysqlDir "\data",
                "Database folder not found:`n" MysqlDir "\data"
            ),
            "UAServer",
            "Iconx"
        )
        return
    }

    try {
        WritePhpConfig()
        WriteMysqlConfig()
        WriteNginxConfig()
        BuildStartPage()

        nginxPrefix := NginxPath(NginxDir) "/"

        testCommand := '"' NginxExe '" -t -p "' nginxPrefix '" -c "' NginxConf '"'

        testResult := RunWait(testCommand, NginxDir, "Hide")

        if testResult != 0
            throw Error("Nginx не пройшов перевірку конфігурації. Перевір logs/nginx_error.log.")

        ; PHP FastCGI.
        phpCommand := '"' PhpExe '" -b 127.0.0.1:' PhpPort ' -c "' PhpIni '"'

        Run(phpCommand, PhpDir, "Hide", &PhpPID)

        Sleep(700)

        if !ProcessExist(PhpPID)
            throw Error("PHP FastCGI не запустився.")

        ; Перед запуском MariaDB перевіряємо,
        ; чи немає вже активного процесу цього UAServer.
        existingMysqlPID := FindLocalMysqlPID()

        if existingMysqlPID {
            if MysqlIsReady() {
                MysqlPID := existingMysqlPID
            } else {
                throw Error(
                    "Знайдено процес MariaDB UAServer (PID "
                    . existingMysqlPID
                    . "), але він ще не готовий приймати підключення."
                    . "`nНовий процес не запускався, щоб не пошкодити бази даних."
                )
            }
        } else {
            ; Запускаємо MariaDB.
            mysqlCommand := '"' MysqlExe '" --defaults-file="' MysqlIni '"'

            Run(mysqlCommand, MysqlDir, "Hide", &MysqlPID)

            ; Чекаємо реальної готовності SQL-сервера.
            if !WaitForMysqlReady(25000) {
                logPath := BaseDir "\logs\mysql_error.log"

                throw Error(
                    "MariaDB не стала доступною протягом 25 секунд."
                    . "`nПеревір журнал: " logPath
                )
            }

            ; Переконуємося, що PID належить нашому серверу.
            actualMysqlPID := FindLocalMysqlPID()

            if actualMysqlPID
                MysqlPID := actualMysqlPID
        }

        ; Nginx запускаємо тільки після готовності бази.
        nginxCommand := '"' NginxExe '" -p "' nginxPrefix '" -c "' NginxConf '"'

        Run(nginxCommand, NginxDir, "Hide", &NginxPID)

        Sleep(700)

        if !ProcessExist(NginxPID)
            throw Error("Nginx не запустився. Перевір logs/nginx_error.log.")

        ServerStarted := true

        BuildStartPage()
        UpdateMenu()

        TrayTip(
            "UAServer Free",
            L("Локальний сервер запущено.", "Local server started."),
            2
        )

    } catch as err {
        ServerStarted := false

        ; При помилці намагаємося штатно зупинити
        ; тільки процеси цього UAServer.
        StopServer()

        MsgBox(
            L("Помилка запуску:`n", "Startup error:`n")
            . err.Message,
            "UAServer",
            "Iconx"
        )
    }
}

; ============================================================
; ЗУПИНКА СЕРВЕРА
; ============================================================

StopServer(*) {
    global NginxExe, NginxDir, NginxConf
    global MysqlAdminExe, MysqlIni, MysqlDir, MysqlPort
    global NginxPID, PhpPID, MysqlPID
    global ServerStarted

    stopFailed := false

    ; --------------------------------------------------------
    ; NGINX
    ; --------------------------------------------------------

    try {
        if FileExist(NginxExe) && FileExist(NginxConf) {
            nginxPrefix := NginxPath(NginxDir) "/"

            stopCommand := '"' NginxExe '" -p "' nginxPrefix '" -c "' NginxConf '" -s quit'

            RunWait(stopCommand, NginxDir, "Hide")
        }
    } catch {
    }

    ; Чекаємо завершення PHP та Nginx.
    if PhpPID && ProcessExist(PhpPID) {
        try ProcessClose(PhpPID)
    }

    PhpPID := 0

    if NginxPID {
        startedAt := A_TickCount

        while ProcessExist(NginxPID) && (A_TickCount - startedAt < 5000)
            Sleep(200)

        if !ProcessExist(NginxPID)
            NginxPID := 0
    }

    ; --------------------------------------------------------
    ; MYSQL / MARIADB
    ; --------------------------------------------------------

    ; Знаходимо саме наш mysqld.exe за повним шляхом.
    localPID := FindLocalMysqlPID()

    if localPID {
        MysqlPID := localPID

        if !FileExist(MysqlAdminExe) {
            stopFailed := true
        } else {
            ; ВАЖЛИВО:
            ; Явно вказуємо root, інакше клієнт
            ; використовує ім'я користувача Windows.
            ;
            ; --no-defaults ставиться першим параметром,
            ; щоб не підхоплювати сторонні налаштування.

            mysqlStopCommand := '"' MysqlAdminExe '" --no-defaults'
                . ' -u root -h 127.0.0.1 -P ' MysqlPort
                . ' shutdown'

            try {
                RunWait(mysqlStopCommand, MysqlDir, "Hide")
            } catch {
            }

            ; Даємо серверу час штатно закрити файли бази.
            startedAt := A_TickCount

            while ProcessExist(localPID) && (A_TickCount - startedAt < 15000)
                Sleep(250)

            if ProcessExist(localPID) {
                stopFailed := true
            } else {
                MysqlPID := 0
            }
        }
    } else {
        MysqlPID := 0
    }

    ServerStarted := false

    UpdateMenu()

    try BuildStartPage()

    if stopFailed {
        MsgBox(
            L(
                "Не вдалося штатно зупинити MariaDB."
                . "`n`nНовий процес не запускатиметься, щоб не пошкодити бази даних."
                . "`n`nПеревір logs/mysql_error.log.",
                "MariaDB could not be stopped normally."
                . "`n`nA new process will not be started to protect your databases."
                . "`n`nCheck logs/mysql_error.log."
            ),
            "UAServer",
            "Iconx"
        )

        return false
    }

    return true
}

; ============================================================
; ВІДКРИТИ САЙТ
; ============================================================

OpenSite(folder) {
    global CurPort

    portSuffix := CurPort = 80 ? "" : ":" CurPort

    Run("http://localhost" portSuffix "/" UriEncodePath(folder) "/")
}

CreateSiteHandler(folder) {
    return (*) => OpenSite(folder)
}

; ============================================================
; МЕНЮ САЙТІВ
; ============================================================

BuildSitesMenu() {
    sitesMenu := Menu()
    sites := GetSiteList()

    if sites.Length = 0 {
        sitesMenu.Add(L("(немає сайтів)", "(no websites)"), (*) => 0)
        return sitesMenu
    }

    for site in sites
        sitesMenu.Add(site.name, CreateSiteHandler(site.folder))

    return sitesMenu
}

; ============================================================
; ГОЛОВНЕ МЕНЮ
; ============================================================

UpdateMenu() {
    global CurPort, WwwDir, LogsDir, CurPHP

    tray := A_TrayMenu
    tray.Delete()

    portSuffix := CurPort = 80 ? "" : ":" CurPort

    tray.Add(
        L("🌍 Відкрити localhost", "🌍 Open localhost"),
        (*) => Run("http://localhost" portSuffix "/")
    )

    tray.Add(
        L("🗄 phpMyAdmin", "🗄 phpMyAdmin"),
        (*) => Run("http://localhost" portSuffix "/phpmyadmin/")
    )

    tray.Add()

    sitesMenu := BuildSitesMenu()

    tray.Add(L("📁 Мої сайти", "📁 My sites"), sitesMenu)

    tray.Add()

    phpMenu := Menu()

    phpMenu.Add("PHP 7.4", (*) => SetPHP("7.4"))
    phpMenu.Add("PHP 8.5", (*) => SetPHP("8.5"))

    if CurPHP = "7.4"
        phpMenu.Check("PHP 7.4")
    else
        phpMenu.Check("PHP 8.5")

    tray.Add(L("⚙ Версія PHP", "⚙ PHP version"), phpMenu)

    tray.Add(
        L("📝 Відкрити php.ini", "📝 Open php.ini"),
        OpenPhpIni
    )

    tray.Add()

    tray.Add(
        L("🔄 Перезапустити сервер", "🔄 Restart server"),
        StartServer
    )

    tray.Add(
        L("⏹ Зупинити сервер", "⏹ Stop server"),
        StopServer
    )

    tray.Add()

    tray.Add(
        L("📂 Відкрити www", "📂 Open www"),
        (*) => Run('explorer.exe "' WwwDir '"')
    )

    tray.Add(
        L("📂 Відкрити logs", "📂 Open logs"),
        (*) => Run('explorer.exe "' LogsDir '"')
    )

    tray.Add()

    tray.Add(L("🌐 Мова", "🌐 Language"), ShowLanguageSelector)

    tray.Add()

    tray.Add(L("ℹ Про програму", "ℹ About"), ShowAbout)
    tray.Add(L("❌ Вийти", "❌ Exit"), ExitUAServer)
}

; ============================================================
; ПРО ПРОГРАМУ
; ============================================================

ShowAbout(*) {
    global AppVersion

    MsgBox(
        "UAServer Free " AppVersion
        . "`n`n"
        . L(
            "Портативний локальний сервер."
            . "`nNginx + PHP + MariaDB/MySQL."
            . "`nУкраїнська та англійська мови.",
            "Portable local server."
            . "`nNginx + PHP + MariaDB/MySQL."
            . "`nUkrainian and English languages."
        ),
        "UAServer Free",
        "Iconi"
    )
}

; ============================================================
; ПЕРЕВІРКА ОНОВЛЕНЬ GITHUB
; ============================================================

CheckForUpdates(*) {
    global AppVersion

    apiUrl := "https://api.github.com/repos/portallcomua/uaserver/releases/latest"
    releaseUrl := "https://github.com/portallcomua/uaserver/releases/latest"

    try {
        request := ComObject("WinHttp.WinHttpRequest.5.1")

        request.SetTimeouts(1500, 1500, 2500, 2500)
        request.Open("GET", apiUrl, false)

        request.SetRequestHeader("User-Agent", "UAServer-Free")
        request.SetRequestHeader("Accept", "application/vnd.github+json")

        request.Send()

        if request.Status != 200
            return

        responseText := request.ResponseText

        if !RegExMatch(responseText, '"tag_name"\s*:\s*"([^"]+)"', &match)
            return

        latestVersion := match[1]

        latestNormalized := RegExReplace(latestVersion, "^v", "")
        currentNormalized := RegExReplace(AppVersion, "^v", "")

        if VerCompare(latestNormalized, currentNormalized) > 0 {
            answer := MsgBox(
                L(
                    "Доступна нова версія: " latestVersion
                    . "`nВстановлена версія: " AppVersion
                    . "`n`nВідкрити сторінку релізу GitHub?"
                    . "`nОновлення поки встановлюється вручну.",
                    "New version available: " latestVersion
                    . "`nInstalled version: " AppVersion
                    . "`n`nOpen GitHub release page?"
                    . "`nUpdates must currently be installed manually."
                ),
                "UAServer Free",
                "YesNo Iconi"
            )

            if answer = "Yes"
                Run(releaseUrl)
        }
    } catch {
    }
}

; ============================================================
; ВИХІД
; ============================================================

ExitUAServer(*) {
    if !StopServer()
        return

    ExitApp()
}

; ============================================================
; ЗАПУСК ПРОГРАМИ
; ============================================================

LoadSettings()

UpdatePaths()
CreateDirs()
CreateDesktopShortcut()

iconPath := BaseDir "\logo.ico"

if FileExist(iconPath)
    TraySetIcon(iconPath)

UpdateMenu()

StartServer()

if ServerStarted {
    portSuffix := CurPort = 80 ? "" : ":" CurPort

    Run("http://localhost" portSuffix "/")
}

SetTimer(CheckForUpdates, -5000)
