#Requires AutoHotkey v2.0
#NoTrayIcon
Persistent
#SingleInstance Force

; ============================================================
;                   UAServer - Локальний сервер
; ============================================================
; Версія: 7.2 - ТОТАЛЬНЕ ПРИДУШЕННЯ ВИВОДУ ПОМИЛОК PHP ЧЕРЕЗ NGINX
; ============================================================

global AppName    := "UAServer"
global BaseDir    := A_ScriptDir
global CurPHP     := "8.5"
global CurPort    := 80
global PhpPort    := 9000

; Базові директорії
global NginxDir   := BaseDir . "\bin\nginx"
global PhpDir     := BaseDir . "\bin\php85"
global MysqlDir   := BaseDir . "\bin\mysql"
global WwwDir     := BaseDir . "\www"
global TmpDir     := BaseDir . "\tmp"
global LogsDir    := BaseDir . "\logs"

CreateDirs() {
    dirs := [
        TmpDir,
        TmpDir . "\session",
        LogsDir,
        WwwDir,
        NginxDir . "\logs"
    ]
    for dir in dirs {
        if !DirExist(dir)
            DirCreate(dir)
    }
}

StartServer() {
    global BaseDir, CurPHP, CurPort, PhpPort, NginxDir, PhpDir, MysqlDir, WwwDir, TmpDir, LogsDir
    
    StopServer()
    Sleep(600)
    CreateDirs()

    ; Formating paths for Nginx
    fixedWww   := StrReplace(WwwDir, "\", "/")
    fixedBin   := StrReplace(BaseDir . "\bin", "\", "/")
    fixedTmp   := StrReplace(TmpDir, "\", "/")
    fixedLogs  := StrReplace(LogsDir, "\", "/")
    fixedMysql := StrReplace(MysqlDir, "\", "/")

    ; Генерируємо блоки підпапок
    sitesList := GetSiteList()
    dynamicLocations := ""
    
    for site in sitesList {
        dynamicLocations .= "        # Динамічний блок для сайту: " site.name " `n"
            . "        location /" site.folder " { `n"
            . "            try_files $uri $uri/ /" site.folder "/index.php?$args; `n"
            . "        } `n`n"
    }

    ; 1. ГЕНЕРАЦІЯ NGINX.CONF (Жорстке блокування display_errors на рівні FastCGI)
    NginxConf := NginxDir . "\conf\nginx.conf"
    ConfNginx := "worker_processes auto; `n"
        . "events { worker_connections 1024; } `n"
        . "http { `n"
        . "    include mime.types; `n"
        . "    default_type application/octet-stream; `n"
        . "    charset utf-8; `n"
        . "    client_max_body_size 1024M; `n"
        . "    sendfile on; `n"
        . "    tcp_nopush on; `n"
        . "    tcp_nodelay on; `n"
        . "    keepalive_timeout 65; `n"
        . "    client_header_timeout 1800; `n"
        . "    client_body_timeout 1800; `n"
        . "    send_timeout 1800; `n"
        . "    server { `n"
        . "        listen " CurPort "; `n"
        . "        server_name localhost; `n"
        . "        root '" fixedWww "'; `n"
        . "        index index.php index.html index.htm; `n"
        . "        autoindex on; `n"
        . "        location / { `n"
        . "            try_files $uri $uri/ /index.php?$args; `n"
        . "        } `n`n"
        . dynamicLocations 
        . "        location ^~ /phpmyadmin { `n"
        . "            alias '" fixedBin "/phpmyadmin'; `n"
        . "            index index.php; `n"
        . "            client_max_body_size 1024M; `n"
        . "            location ~ \.php$ { `n"
        . "                fastcgi_pass 127.0.0.1:" PhpPort "; `n"
        . "                fastcgi_index index.php; `n"
        . "                fastcgi_param SCRIPT_FILENAME $request_filename; `n"
        . "                include fastcgi_params; `n"
        . "            } `n"
        . "        } `n"
        . "        location ~ \.php$ { `n"
        . "            fastcgi_pass 127.0.0.1:" PhpPort "; `n"
        . "            fastcgi_index index.php; `n"
        . "            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; `n"
        . "            include fastcgi_params; `n"
        . "            fastcgi_read_timeout 1800; `n"
        . "            fastcgi_buffers 16 16k; `n"
        . "            fastcgi_buffer_size 32k; `n"
        . "            # ФІКС: Жорстко забороняємо PHP виводити помилки на екран, ігноруючи налаштування рушіїв `n"
        . "            fastcgi_param PHP_VALUE 'display_errors=Off `n error_reporting=0'; `n"
        . "        } `n"
        . "    } `n"
        . "}"
    if FileExist(NginxConf)
        FileDelete(NginxConf)
    FileAppend(ConfNginx, NginxConf, "UTF-8-RAW")

    ; 2. ГЕНЕРАЦІЯ PHP.INI
    PhpIni := PhpDir . "\php.ini"
    ConfPhp := "[PHP]`n"
        . "engine = On`nshort_open_tag = Off`nprecision = 14`noutput_buffering = 4096`nzlib.output_compression = Off`nimplicit_flush = Off`nunserialize_callback_func =`nserialize_precision = -1`ndisable_functions =`ndisable_classes =`nzend.enable_gc = On`nexpose_php = Off`nmax_execution_time = 1800`nmax_input_time = 1800`nmax_input_vars = 10000`nmemory_limit = 1024M`n"
        . "error_reporting = E_ALL & ~E_NOTICE & ~E_WARNING & ~E_DEPRECATED & ~E_STRICT`n" 
        . "display_errors = Off`n" 
        . "display_startup_errors = Off`n"
        . "log_errors = On`n" 
        . "log_errors_max_len = 1024`nignore_repeated_errors = Off`nignore_repeated_source = Off`nreport_memleaks = On`nvariables_order = 'GPCS'`nrequest_order = 'GP'`nregister_argc_argv = Off`nauto_globals_jit = On`npost_max_size = 1024M`nfile_uploads = On`nupload_max_filesize = 1024M`nmax_file_uploads = 20`nallow_url_fopen = On`nallow_url_include = Off`ndefault_socket_timeout = 1800`n"
        . "[Date]`ndate.timezone = 'Europe/Kiev'`n"
        . "[Session]`nsession.save_handler = files`n"
        . "session.save_path = '" fixedTmp "/session'`n"
        . "session.use_strict_mode = 0`nsession.use_cookies = 1`nsession.use_only_cookies = 1`nsession.name = PHPSESSID`nsession.auto_start = 0`nsession.cookie_lifetime = 0`nsession.cookie_path = /`nsession.cookie_handler = php`nsession.gc_probability = 1`nsession.gc_divisor = 100`nsession.gc_maxlifetime = 1440`n"
        . "extension_dir = 'ext'`nextension=curl`nextension=gd`nextension=mbstring`nextension=openssl`nextension=zip`nextension=fileinfo`nextension=intl`nextension=mysqli`nextension=pdo_mysql`n"
        . "opcache.enable=1`nopcache.memory_consumption=256`nopcache.max_accelerated_files=20000`nopcache.revalidate_freq=0`n"
        . "error_log = '" fixedLogs "/php_error.log'`n"
    if FileExist(PhpIni)
        FileDelete(PhpIni)
    FileAppend(ConfPhp, PhpIni, "UTF-8-RAW")

    ; 3. ГЕНЕРАЦІЯ MY.INI
    MyIni := MysqlDir . "\my.ini"
    ConfMysql := "[client]`nport=3306`ndefault-character-set=utf8mb4`n"
        . "[mysql]`ndefault-character-set=utf8mb4`n"
        . "[mysqld]`nport=3306`n"
        . "basedir='" fixedMysql "'`n"
        . "datadir='" fixedMysql "/data'`n"
        . "tmpdir='" fixedTmp "'`n"
        . "socket='" fixedMysql "/mysql.sock'`n"
        . "pid-file='" fixedMysql "/mysql.pid'`n"
        . "character-set-server=utf8mb4`ncollation-server=utf8mb4_unicode_ci`ninit-connect='SET NAMES utf8mb4'`n"
        . "max_connections=60`nkey_buffer_size=64M`nmax_allowed_packet=500M`ntmp_table_size=64M`nmax_heap_table_size=64M`ndefault_storage_engine=InnoDB`n"
        . "innodb_buffer_pool_size=512M`n"
        . "innodb_log_buffer_size=16M`n"
        . "innodb_flush_log_at_trx_commit=2`n"
        . "innodb_lock_wait_timeout=50`n"
        . "innodb_io_capacity=1000`n"
        . "log_error='" fixedLogs "/mysql_error.log'`n"
        . "explicit_defaults_for_timestamp=true`nsql_mode=NO_ENGINE_SUBSTITUTION`n"
    if FileExist(MyIni)
        FileDelete(MyIni)
    FileAppend(ConfMysql, MyIni, "UTF-8-RAW")

    ; ЗАПУСК СЛУЖБ
    try {
        RunWait(A_ComSpec ' /c taskkill /f /im php-cgi.exe', , "Hide")
        RunWait(A_ComSpec ' /c taskkill /f /im nginx.exe', , "Hide")
        RunWait(A_ComSpec ' /c taskkill /f /im mysqld.exe', , "Hide")
        Sleep(600)

        ; Запуск PHP
        Run(A_ComSpec ' /c start "" /b "' PhpDir '\php-cgi.exe" -b 127.0.0.1:' PhpPort ' -c "' PhpIni '"', PhpDir, "Hide")
        Sleep(600)

        ; Запуск MySQL
        if FileExist(MysqlDir . "\bin\mysqld.exe") {
            Run(A_ComSpec ' /c start "" /b "' MysqlDir '\bin\mysqld.exe" --defaults-file="' MyIni '" --standalone', MysqlDir, "Hide")
        }
        Sleep(600)

        ; Запуск Nginx
        SetWorkingDir(NginxDir)
        Run(A_ComSpec ' /c start "" /b nginx.exe', NginxDir, "Hide")
        SetWorkingDir(BaseDir)
        
        if FileExist(BaseDir . "\logo.ico")
            TraySetIcon(BaseDir . "\logo.ico")
        A_IconHidden := false
        UpdateMenu()
        
        TrayTip("UAServer", "✅ Сервер перезапущено, помилки заблоковано!", 2)
    } catch as err {
        MsgBox("❌ Сталася критична помилка: " err.Message, "Помилка", 48)
    }
}

StopServer(*) {
    try {
        RunWait(A_ComSpec ' /c taskkill /f /im nginx.exe', , "Hide")
        RunWait(A_ComSpec ' /c taskkill /f /im php-cgi.exe', , "Hide")
        RunWait(A_ComSpec ' /c taskkill /f /im mysqld.exe', , "Hide")
    }
}

UpdateMenu() {
    global CurPort, BaseDir, WwwDir
    Tray := A_TrayMenu
    Tray.Delete()
    p := (CurPort == 80) ? "" : ":" CurPort

    Tray.Add("🌍 Відкрити localhost", (*) => Run("http://localhost" p "/"))
    Tray.Add("📊 phpMyAdmin", (*) => Run("http://localhost" p "/phpmyadmin/"))
    Tray.Add()

    SitesMenu := Menu()
    sites := GetSiteList()
    if sites.Length > 0 {
        for site in sites {
            CreateSiteHandler(folderPath) {
                return (*) => Run("http://localhost" p "/" folderPath)
            }
            SitesMenu.Add(site.name, CreateSiteHandler(site.folder))
        }
    } else {
        SitesMenu.Add("(немає сайтів)", "")
    }
    Tray.Add("📁 Мої сайти", SitesMenu)
    Tray.Add()

    PhpMenu := Menu()
    PhpMenu.Add("PHP 7.4", (*) => SetPHP("7.4"))
    PhpMenu.Add("PHP 8.5", (*) => SetPHP("8.5"))
    (CurPHP == "7.4") ? PhpMenu.Check("PHP 7.4") : PhpMenu.Check("PHP 8.5")
    Tray.Add("⚙️ Версія PHP", PhpMenu)
    Tray.Add()

    Tray.Add("🔄 Перезапустити сервер", (*) => (StopServer(), StartServer()))
    Tray.Add("⏹️ Зупинити сервер", StopServer)
    Tray.Add()
    Tray.Add("📂 Відкрити www", (*) => Run("explorer.exe `"" WwwDir "`""))
    Tray.Add("📂 Відкрити logs", (*) => Run("explorer.exe `"" BaseDir "\logs`""))
    Tray.Add()
    Tray.Add("❌ Вийти", (*) => (StopServer(), ExitApp()))
}

GetSiteList() {
    global WwwDir
    sites := []
    if DirExist(WwwDir) {
        loop files WwwDir "\*", "D" {
            if FileExist(WwwDir "\" A_LoopFileName "\index.php") 
               or FileExist(WwwDir "\" A_LoopFileName "\index.html")
               or FileExist(WwwDir "\" A_LoopFileName "\index.htm") {
                sites.Push({name: A_LoopFileName, folder: A_LoopFileName})
            }
        }
    }
    return sites
}

SetPHP(ver) {
    global CurPHP
    CurPHP := ver
    UpdateMenu()
    if ProcessExist("nginx.exe")
        StartServer()
}

; СТАРТ
StartServer()