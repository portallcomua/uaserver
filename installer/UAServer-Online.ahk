#Requires AutoHotkey v2.0
#SingleInstance Force

AppName := "UAServer Free"
FullUrl := "https://github.com/portallcomua/uaserver/releases/latest/download/UAServer-Full.zip"
DefaultDir := "D:\UAServer"

if !DirExist(DefaultDir)
    DirCreate(DefaultDir)

targetDir := DirSelect(DefaultDir, 1, "Оберіть папку для встановлення UAServer Free")
if targetDir = ""
    ExitApp

if FileExist(targetDir "\UAServer.exe") || DirExist(targetDir "\bin") {
    MsgBox("Папка вже містить UAServer або bin. Оберіть порожню папку, щоб не перезаписати сайти та бази даних.", AppName, "Icon!")
    ExitApp
}

zipPath := A_Temp "\UAServer-Full-" A_TickCount ".zip"
TrayTip("UAServer Free", "Завантаження повного архіву. Зачекайте...", 1)
try {
    Download(FullUrl, zipPath)
} catch as err {
    TrayTip()
    MsgBox("Не вдалося завантажити UAServer-Full.zip. " err.Message, AppName, "Iconx")
    ExitApp
}
TrayTip()

if !FileExist(zipPath) {
    MsgBox("Архів не завантажився.", AppName, "Iconx")
    ExitApp
}

TrayTip("UAServer Free", "Розпакування компонентів...", 1)
q := Chr(34)
sq := "'"
psCommand := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
    . q "Expand-Archive -LiteralPath " sq zipPath sq " -DestinationPath " sq targetDir sq " -Force" q

try {
    exitCode := RunWait(psCommand, , "Hide")
} catch as err {
    TrayTip()
    MsgBox("Не вдалося розпакувати архів. " err.Message, AppName, "Iconx")
    try FileDelete(zipPath)
    ExitApp
}
TrayTip()
try FileDelete(zipPath)

if exitCode != 0 || !FileExist(targetDir "\UAServer.exe") {
    MsgBox("Встановлення не завершилося: не знайдено UAServer.exe.", AppName, "Iconx")
    ExitApp
}

iconPath := targetDir "\logo.ico"
if !FileExist(iconPath)
    iconPath := targetDir "\UAServer.exe"

try FileCreateShortcut(targetDir "\UAServer.exe", A_Desktop "\UAServer.lnk", targetDir, "", "Запуск UAServer Free", iconPath)

MsgBox("UAServer Free встановлено! Папка: " targetDir ". Створено ярлик UAServer на робочому столі. Натисніть OK для запуску.", AppName, "Iconi")
Run('"' targetDir "\UAServer.exe" '"', targetDir)
ExitApp
