#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance Force
SetWorkingDir, %A_ScriptDir%

DefaultCloseAccount := "+s:YOUR_STEAM_ID:0"
DefaultKillSteam := "C:\Path\To\kill-steam.exe"
TcNoPath := "C:\Program Files\TcNo Account Switcher\TcNo-Acc-Switcher.exe"
TcNoMainPath := "C:\Program Files\TcNo Account Switcher\TcNo-Acc-Switcher_main.exe"

if (A_Args.Length() < 1) {
    SteamCli_ShowUsage()
    ExitApp
}

Command := A_Args[1]

if (Command = "start") {
    if (A_Args.Length() < 3) {
        SteamCli_ShowUsage()
        ExitApp
    }

    AccountArguments := A_Args[2]
    SteamGameId := A_Args[3]
    GameName := A_Args.Length() >= 4 ? A_Args[4] : SteamGameId
    KillSteamPath := A_Args.Length() >= 5 ? A_Args[5] : DefaultKillSteam

    SteamCli_Start(GameName, AccountArguments, SteamGameId, KillSteamPath)
    ExitApp
}

if (Command = "switch") {
    if (A_Args.Length() < 2) {
        SteamCli_ShowUsage()
        ExitApp
    }

    AccountArguments := A_Args[2]
    SteamCli_Switch(AccountArguments)
    ExitApp
}

if (Command = "preview") {
    PreviewMode := A_Args.Length() >= 2 ? A_Args[2] : "start"
    AccountArguments := A_Args.Length() >= 3 ? A_Args[3] : DefaultCloseAccount
    SteamGameId := A_Args.Length() >= 4 ? A_Args[4] : "3017860"
    GameName := A_Args.Length() >= 5 ? A_Args[5] : "Preview Game"

    SteamCli_Preview(PreviewMode, GameName, AccountArguments, SteamGameId)
    ExitApp
}

if (Command = "close") {
    AccountArguments := A_Args.Length() >= 2 ? A_Args[2] : DefaultCloseAccount
    KillSteamPath := A_Args.Length() >= 3 ? A_Args[3] : DefaultKillSteam
    ExtraKillList := A_Args.Length() >= 4 ? A_Args[4] : ""
    GameName := A_Args.Length() >= 5 ? A_Args[5] : "Steam"

    SteamCli_Close(GameName, AccountArguments, KillSteamPath, ExtraKillList)
    ExitApp
}

SteamCli_ShowUsage()
ExitApp

SteamCli_Start(GameName, AccountArguments, SteamGameId, KillSteamPath, DelayMs := 1500) {
    SteamCli_LoadingStart("Starting " . GameName, "Preparing Steam launch...", "Game: " . GameName . "`nSteam ID: " . SteamGameId . "`nAccount: " . AccountArguments, 5)

    Process, Exist, steamservice.exe
    SteamWasRunning := ErrorLevel

    if (SteamWasRunning) {
        SteamCli_LoadingUpdate("Steam is already running.", "Closing Steam before account switch...", 20)
        Run, %KillSteamPath%,, Hide
        SteamCli_WaitForProcessExit("steamservice.exe", "Closing Steam...", "Waiting for steamservice.exe to exit...", 20, 45, 30000)
    } else {
        SteamCli_LoadingUpdate("Steam is not running.", "No Steam shutdown needed.", 45)
    }

    SteamCli_LoadingUpdate("Switching Steam account...", "Running TcNo hidden: " . AccountArguments, 55)
    SteamCli_RunTcNo(AccountArguments)
    SteamCli_LoadingWait(DelayMs, 55, 80, "Switching account...", "Waiting for TcNo to apply the account change...")

    SteamCli_LoadingUpdate("Launching Steam game...", "Running steam://rungameid/" . SteamGameId . """ -silent", 90)
    Run, steam://rungameid/%SteamGameId%" -silent
    SteamCli_LoadingDone("Launch command sent.", "Steam should now open " . GameName . ".")
}

SteamCli_Switch(AccountArguments, DelayMs := 1500) {
    SteamCli_LoadingStart("Switching Steam", "Switching Steam account...", "Account: " . AccountArguments, 30)
    SteamCli_RunTcNo(AccountArguments)
    SteamCli_LoadingWait(DelayMs, 30, 70, "Switching account...", "Waiting for TcNo to apply the account change...")

    SteamCli_LoadingUpdate("Launching Steam...", "Opening Steam main window.", 90)
    Run, steam://open/main
    SteamCli_LoadingDone("Steam launch command sent.", "Steam should now open on the selected account.")
}

SteamCli_Close(GameName, AccountArguments, KillSteamPath, ExtraKillList := "", WaitTimeoutMs := 60000) {
    SteamCli_LoadingStart("Closing " . GameName, "Closing Steam...", "Switch-back account: " . AccountArguments, 10)

    Run, %KillSteamPath%,, Hide
    SteamCli_WaitForProcessExit("steamservice.exe", "Closing Steam...", "Waiting for steamservice.exe to exit...", 10, 70, WaitTimeoutMs)

    SteamCli_LoadingUpdate("Switching back to default account...", "Running TcNo hidden: " . AccountArguments, 80)
    SteamCli_RunTcNo(AccountArguments)

    if (ExtraKillList != "") {
        SteamCli_LoadingUpdate("Cleaning up extra processes...", ExtraKillList, 90)
        Loop, Parse, ExtraKillList, |
        {
            ProcessName := Trim(A_LoopField)
            if (ProcessName != "")
                Run, taskkill /f /im %ProcessName%,, Hide
        }
    }

    SteamCli_LoadingDone("Close flow complete.", "Steam was closed and the account switch command was sent.")
}

SteamCli_Preview(PreviewMode, GameName, AccountArguments, SteamGameId) {
    if (PreviewMode = "close") {
        SteamCli_LoadingStart("Closing " . GameName, "Closing Steam...", "Preview only. No processes will be closed.`nSwitch-back account: " . AccountArguments, 10)
        SteamCli_LoadingWait(900, 10, 45, "Closing Steam...", "Preview: waiting for steamservice.exe to exit...")
        SteamCli_LoadingUpdate("Switching back to default account...", "Preview: would run TcNo hidden: " . AccountArguments, 80)
        SteamCli_LoadingWait(700, 80, 95, "Switching back to default account...", "Preview: no account switch was executed.")
        SteamCli_LoadingDone("Preview complete.", "No close, account switch, or cleanup command was run.")
        Return
    }

    if (PreviewMode = "switch") {
        SteamCli_LoadingStart("Switching Steam", "Switching Steam account...", "Preview only.`nAccount: " . AccountArguments, 30)
        SteamCli_LoadingWait(900, 30, 70, "Switching account...", "Preview: would run TcNo hidden.")
        SteamCli_LoadingUpdate("Launching Steam...", "Preview: would open steam://open/main", 90)
        SteamCli_LoadingDone("Preview complete.", "No account switch or Steam launch command was run.")
        Return
    }

    SteamCli_LoadingStart("Starting " . GameName, "Preparing Steam launch...", "Preview only.`nGame: " . GameName . "`nSteam ID: " . SteamGameId . "`nAccount: " . AccountArguments, 5)
    SteamCli_LoadingUpdate("Steam is already running.", "Preview: would close Steam before account switch.", 20)
    SteamCli_LoadingWait(900, 20, 45, "Closing Steam...", "Preview: waiting for steamservice.exe to exit...")
    SteamCli_LoadingUpdate("Switching Steam account...", "Preview: would run TcNo hidden: " . AccountArguments, 55)
    SteamCli_LoadingWait(900, 55, 80, "Switching account...", "Preview: waiting for TcNo to apply the account change...")
    SteamCli_LoadingUpdate("Launching Steam game...", "Preview: would run steam://rungameid/" . SteamGameId . """ -silent", 90)
    SteamCli_LoadingDone("Preview complete.", "No Steam, TcNo, or game launch command was run.")
}

SteamCli_RunTcNo(AccountArguments) {
    global TcNoMainPath
    Shell := ComObjCreate("WScript.Shell")
    FullCommand := """" . TcNoMainPath . """ " . AccountArguments
    Shell.Run(FullCommand, 0, false)
}

SteamCli_WaitForProcessExit(ProcessName, Message, Detail, StartPercent, EndPercent, TimeoutMs) {
    StartTick := A_TickCount

    Loop {
        Process, Exist, %ProcessName%
        if (!ErrorLevel)
            Break

        Elapsed := A_TickCount - StartTick
        if (Elapsed >= TimeoutMs)
            Break

        Percent := StartPercent + Round((EndPercent - StartPercent) * (Elapsed / TimeoutMs))
        Seconds := Round(Elapsed / 1000, 1)
        SteamCli_LoadingUpdate(Message, Detail . "`nElapsed: " . Seconds . "s", Percent)
        Sleep, 500
    }
}

SteamCli_LoadingStart(Title, Message, Detail := "", Percent := 0) {
    global SteamCli_LoadingGuiHwnd
    global SteamCli_LoadingTextHwnd
    global SteamCli_LoadingDetailHwnd
    global SteamCli_LoadingSpinnerHwnd
    global SteamCli_LoadingAnimHwnd
    global SteamCli_LoadingPercentHwnd
    global SteamCli_LoadingProgressHwnd
    global SteamCli_LoadingPercent
    global SteamCli_LoadingAnimFrame

    SteamCli_LoadingPercent := Percent
    SteamCli_LoadingAnimFrame := 0
    SteamCli_LoadingEnsureGdip()

    Gui, SteamCliLoading:New, +AlwaysOnTop -Caption +ToolWindow +HwndSteamCli_LoadingGuiHwnd, %Title%
    Gui, SteamCliLoading:Color, 101823
    Gui, SteamCliLoading:Margin, 0, 0
    Gui, SteamCliLoading:Add, Progress, x0 y0 w420 h50 Background101823 c101823, 100
    Gui, SteamCliLoading:Add, Picture, x12 y11 w28 h28 hwndSteamCli_LoadingSpinnerHwnd
    Gui, SteamCliLoading:Font, s8 cF8FAFF, Segoe UI Semibold
    Gui, SteamCliLoading:Add, Text, x52 y14 w150 h22 BackgroundTrans hwndSteamCli_LoadingTextHwnd, %Title%
    Gui, SteamCliLoading:Add, Progress, x210 y11 w1 h26 Background303846 c303846, 100
    Gui, SteamCliLoading:Font, s8 c7C5CFF, Segoe UI Semibold
    Gui, SteamCliLoading:Add, Text, x224 y14 w64 h22 BackgroundTrans hwndSteamCli_LoadingAnimHwnd, Working
    Gui, SteamCliLoading:Add, Progress, x286 y21 w78 h8 Background202735 c3F2CB8 hwndSteamCli_LoadingProgressHwnd, %Percent%
    Gui, SteamCliLoading:Font, s9 c7C5CFF, Segoe UI Semibold
    Gui, SteamCliLoading:Add, Text, x372 y13 w40 h24 BackgroundTrans hwndSteamCli_LoadingPercentHwnd, %Percent%`%
    Gui, SteamCliLoading:Add, Text, x0 y0 w1 h1 Hidden hwndSteamCli_LoadingDetailHwnd, %Detail%
    Gui, SteamCliLoading:Show, w420 h50 Center
    SteamCli_LoadingRoundWindow(SteamCli_LoadingGuiHwnd, 420, 50, 10)
    SetTimer, SteamCli_LoadingAnimate, 120
}

SteamCli_LoadingUpdate(Message, Detail, Percent) {
    global SteamCli_LoadingTextHwnd
    global SteamCli_LoadingDetailHwnd

    if (Percent < 0)
        Percent := 0
    if (Percent > 100)
        Percent := 100

    GuiControl, SteamCliLoading:, %SteamCli_LoadingTextHwnd%, %Message%
    GuiControl, SteamCliLoading:, %SteamCli_LoadingDetailHwnd%, %Detail%
    SteamCli_LoadingSetProgress(Percent)
}

SteamCli_LoadingSetProgress(TargetPercent) {
    global SteamCli_LoadingProgressHwnd
    global SteamCli_LoadingPercentHwnd
    global SteamCli_LoadingPercent

    if (TargetPercent < 0)
        TargetPercent := 0
    if (TargetPercent > 100)
        TargetPercent := 100

    if (SteamCli_LoadingPercent = "")
        SteamCli_LoadingPercent := 0

    Step := TargetPercent >= SteamCli_LoadingPercent ? 1 : -1
    Loop {
        if (SteamCli_LoadingPercent = TargetPercent)
            Break

        SteamCli_LoadingPercent += Step
        GuiControl, SteamCliLoading:, %SteamCli_LoadingProgressHwnd%, %SteamCli_LoadingPercent%
        GuiControl, SteamCliLoading:, %SteamCli_LoadingPercentHwnd%, %SteamCli_LoadingPercent%`%
        Sleep, 8
    }
}

SteamCli_LoadingWait(DelayMs, StartPercent, EndPercent, Message, Detail := "") {
    if (DelayMs <= 0)
        Return

    Steps := 10
    StepDelay := Max(50, Round(DelayMs / Steps))

    Loop, %Steps%
    {
        Percent := StartPercent + Round((EndPercent - StartPercent) * (A_Index / Steps))
        SteamCli_LoadingUpdate(Message, Detail, Percent)
        Sleep, %StepDelay%
    }
}

SteamCli_LoadingDone(Message := "Done.", Detail := "") {
    SteamCli_LoadingUpdate(Message, Detail, 100)
    Sleep, 700
    SetTimer, SteamCli_LoadingAnimate, Off
    Gui, SteamCliLoading:Destroy
}

SteamCli_LoadingRoundWindow(hwnd, Width, Height, Radius) {
    Region := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", Width + 1, "Int", Height + 1, "Int", Radius, "Int", Radius, "Ptr")
    DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", Region, "Int", true)
}

SteamCli_LoadingCancel:
ExitApp
Return

SteamCli_LoadingAnimate:
global SteamCli_LoadingSpinnerHwnd
SteamCli_LoadingAnimFrame++
if (SteamCli_LoadingAnimFrame > 8)
    SteamCli_LoadingAnimFrame := 1

if (SteamCli_LoadingAnimFrame = 1)
    AnimText := "Working"
else if (SteamCli_LoadingAnimFrame = 2)
    AnimText := "Working ."
else if (SteamCli_LoadingAnimFrame = 3)
    AnimText := "Working .."
else if (SteamCli_LoadingAnimFrame = 4)
    AnimText := "Working ..."
else if (SteamCli_LoadingAnimFrame = 5)
    AnimText := "Working"
else if (SteamCli_LoadingAnimFrame = 6)
    AnimText := "Working ."
else if (SteamCli_LoadingAnimFrame = 7)
    AnimText := "Working .."
else
    AnimText := "Working ..."

SteamCli_LoadingDrawSpinner(Mod((SteamCli_LoadingAnimFrame - 1) * 45, 360))
GuiControl, SteamCliLoading:, %SteamCli_LoadingAnimHwnd%, %AnimText%
Return

SteamCli_LoadingEnsureGdip() {
    global SteamCli_GdipToken
    if (SteamCli_GdipToken)
        Return true

    VarSetCapacity(si, A_PtrSize = 8 ? 24 : 16, 0)
    NumPut(1, si, 0, "UInt")
    return !DllCall("gdiplus\GdiplusStartup", "Ptr*", SteamCli_GdipToken, "Ptr", &si, "Ptr", 0)
}

SteamCli_LoadingDrawSpinner(StartAngle) {
    global SteamCli_LoadingSpinnerHwnd
    global SteamCli_GdipToken

    if (!SteamCli_GdipToken || !SteamCli_LoadingSpinnerHwnd)
        Return

    Size := 28
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", Size, "Int", Size, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", pBitmap)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBitmap, "Ptr*", pGraphics)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", pGraphics, "Int", 4)
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", pGraphics, "UInt", 0x00101823)

    DllCall("gdiplus\GdipCreatePen1", "UInt", 0xFF303846, "Float", 3.0, "Int", 2, "Ptr*", pPenBg)
    DllCall("gdiplus\GdipDrawEllipse", "Ptr", pGraphics, "Ptr", pPenBg, "Float", 5.0, "Float", 5.0, "Float", 18.0, "Float", 18.0)
    DllCall("gdiplus\GdipDeletePen", "Ptr", pPenBg)

    DllCall("gdiplus\GdipCreatePen1", "UInt", 0xFF7C5CFF, "Float", 3.0, "Int", 2, "Ptr*", pPenArc)
    DllCall("gdiplus\GdipDrawArc", "Ptr", pGraphics, "Ptr", pPenArc, "Float", 5.0, "Float", 5.0, "Float", 18.0, "Float", 18.0, "Float", StartAngle, "Float", 270.0)
    DllCall("gdiplus\GdipDeletePen", "Ptr", pPenArc)

    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", pBitmap, "Ptr*", hBitmap, "UInt", 0x00101823)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)

    GuiControl, SteamCliLoading:, %SteamCli_LoadingSpinnerHwnd%, HBITMAP:*%hBitmap%
}

SteamCli_ShowUsage() {
    Usage =
(
Usage:
Steam Game CLI.ahk start <account-args> <steam-game-id> [game-name] [kill-steam-path]
Steam Game CLI.ahk switch <account-args>
Steam Game CLI.ahk preview [start|switch|close] [account-args] [steam-game-id] [game-name]
Steam Game CLI.ahk close [account-args] [kill-steam-path] [extra-processes] [game-name]

Example:
Steam Game CLI.ahk start "+s:YOUR_STEAM_ID:0" 3017860 "My Game"
Steam Game CLI.ahk switch "+s:YOUR_STEAM_ID:0"
Steam Game CLI.ahk preview start "+s:YOUR_STEAM_ID:0" 3017860 "Preview Game"
Steam Game CLI.ahk close
)
    MsgBox, 64, Steam Game CLI, %Usage%
}
