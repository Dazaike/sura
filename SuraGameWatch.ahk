#Requires AutoHotkey v2.0
#SingleInstance Off

; CLI:
;   SuraGameWatch.ahk --status <status-file> <game-exe> [game-name] [window-spec]
;   SuraGameWatch.ahk <game-exe> [window-spec] [game-name] [sura-exe]
;
; Examples:
;   Sura.exe start nsg "Q:\QGames\ODDCORE\ODDCORE.exe" "OddCore"
;   SuraGameWatch.ahk --status "%TEMP%\sura.status" "Q:\QGames\ODDCORE\ODDCORE.exe" "OddCore"
;   SuraGameWatch.ahk "Q:\QGames\ODDCORE\ODDCORE.exe"
;   SuraGameWatch.ahk "Q:\QGames\ODDCORE\ODDCORE.exe" "ahk_exe ODDCORE.exe" "OddCore"
;   SuraGameWatch.ahk "Q:\QGames\ODDCORE\ODDCORE.exe" "ODDCORE" "OddCore" "C:\Path\To\Sura.exe"

if A_Args.Length < 1 {
    MsgBox("Usage:`nSuraGameWatch.ahk --status <status-file> <game-exe> [game-name] [window-spec]`nSuraGameWatch.ahk <game-exe> [window-spec] [game-name] [sura-exe]", "Sura Game Watch")
    ExitApp(2)
}

statusMode := A_Args[1] = "--status"

if statusMode {
    if A_Args.Length < 3 {
        MsgBox("Usage:`nSuraGameWatch.ahk --status <status-file> <game-exe> [game-name] [window-spec]", "Sura Game Watch")
        ExitApp(2)
    }

    statusFile := A_Args[2]
    gameExe := A_Args[3]
    SplitPath(gameExe, &exeName, &gameDir, , &exeStem)
    gameName := A_Args.Length >= 4 && A_Args[4] != "" ? A_Args[4] : exeStem
    windowSpec := A_Args.Length >= 5 && A_Args[5] != "" ? A_Args[5] : "ahk_exe " exeName
} else {
    gameExe := A_Args[1]
    SplitPath(gameExe, &exeName, &gameDir, , &exeStem)
    windowSpec := A_Args.Length >= 2 && A_Args[2] != "" ? A_Args[2] : "ahk_exe " exeName
    gameName := A_Args.Length >= 3 && A_Args[3] != "" ? A_Args[3] : exeStem
    suraExe := A_Args.Length >= 4 && A_Args[4] != "" ? A_Args[4] : A_ScriptDir "\Sura.exe"
    statusFile := A_Temp "\sura-game-watch-" A_TickCount ".status"
}

if !FileExist(gameExe) {
    MsgBox("Game executable was not found:`n" gameExe, "Sura Game Watch")
    ExitApp(3)
}

if !statusMode && !FileExist(suraExe) {
    MsgBox("Sura executable was not found:`n" suraExe, "Sura Game Watch")
    ExitApp(4)
}

WriteStatus(statusFile, "Starting " gameName, 0)

if !statusMode {
    Run('"' suraExe '" watch "' statusFile '"')
    Sleep(250)
}

WriteStatus(statusFile, "Launching game...", 15)
try {
    Run('"' gameExe '"', gameDir)
} catch Error as err {
    WriteStatus(statusFile, "Failed to launch game.", 100)
    MsgBox("Failed to launch game:`n" err.Message, "Sura Game Watch")
    ExitApp(5)
}

WriteStatus(statusFile, "Waiting for game window...", 45)

deadline := A_TickCount + 45000
found := false
while A_TickCount < deadline {
    if WinExist(windowSpec) {
        found := true
        break
    }

    elapsed := 45000 - Max(0, deadline - A_TickCount)
    percent := 45 + Floor((elapsed / 45000) * 45)
    WriteStatus(statusFile, "Waiting for game window...", Min(percent, 90))
    Sleep(250)
}

if found {
    WriteStatus(statusFile, "Game window detected.", 100)
    ExitApp(0)
}

WriteStatus(statusFile, "Window monitor timed out.", 100)
ExitApp(6)

WriteStatus(path, status, percent) {
    tempPath := path ".tmp"
    text := "status=" status "`npercent=" percent "`n"
    try FileDelete(tempPath)
    FileAppend(text, tempPath, "UTF-8")
    try FileDelete(path)
    FileMove(tempPath, path, true)
}
