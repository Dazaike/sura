#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; Sura Command Generator
; Interactive GUI to build, validate, test, and export Sura CLI launch commands
; ==============================================================================

SetWorkingDir(A_ScriptDir)

; Global UI State & References
global AppTitle := "Sura Command Generator"
global MainGui := ""

global ModeChoice := ""
global AccountEdit := ""
global AppIdEdit := ""
global GameNameEdit := ""
global PreviewModeChoice := ""

global CommandOutputEdit := ""
global StatusBarCtrl := ""

CreateGeneratorGui()

; ------------------------------------------------------------------------------
; GUI Creation & Layout
; ------------------------------------------------------------------------------
CreateGeneratorGui() {
    global MainGui, AppTitle
    global ModeChoice, AccountEdit, AppIdEdit, GameNameEdit, PreviewModeChoice
    global CommandOutputEdit, StatusBarCtrl

    MainGui := Gui("+Resize +MinSize620x540", AppTitle)
    MainGui.SetFont("s9", "Segoe UI")
    MainGui.MarginX := 16
    MainGui.MarginY := 14

    ; Header
    MainGui.SetFont("s13 bold", "Segoe UI")
    MainGui.Add("Text", "w580 c1E293B", "Sura CLI Command Generator")
    MainGui.SetFont("s9 norm", "Segoe UI")
    MainGui.Add("Text", "w580 c64748B y+2", "Build and export launch commands for Sura (Steam, Non-Steam, TcNo Switcher)")

    ; Group 1: Command Mode
    MainGui.Add("GroupBox", "xs w580 r2.5 y+12 Section", "1. Command Mode")
    ModeList := [
        "start — Steam game with account switch",
        "start<appid> — Steam game direct launch (no switch)",
        "start nsg — Non-Steam game with progress watcher",
        "switch — Switch Steam account only",
        "close — Close Steam & revert to default account",
        "preview — Dry-run preview loading UI",
        "watch — Monitor custom status file"
    ]
    ModeChoice := MainGui.Add("DropDownList", "xs+14 ys+24 w552 Choose1", ModeList)
    ModeChoice.OnEvent("Change", OnModeChange)

    ; Group 2: Command Parameters
    MainGui.Add("GroupBox", "xs w580 r4.8 y+16 Section", "2. Parameters")

    ; Row: Account
    MainGui.Add("Text", "xs+14 ys+24 w130", "Account String:")
    AccountEdit := MainGui.Add("Edit", "x+10 yp-3 w412", "+s:YOUR_STEAM_ID:0")
    AccountEdit.OnEvent("Change", (*) => UpdateCommand())

    ; Row: Steam App ID
    MainGui.Add("Text", "xs+14 y+10 w130", "Steam App ID:")
    AppIdEdit := MainGui.Add("Edit", "x+10 yp-3 w412", "3017860")
    AppIdEdit.OnEvent("Change", OnAppIdChange)

    ; Row: Game
    MainGui.Add("Text", "xs+14 y+10 w130", "Game:")
    GameNameEdit := MainGui.Add("Edit", "x+10 yp-3 w412", "My Game")
    GameNameEdit.OnEvent("Change", (*) => UpdateCommand())

    ; Row: Preview Mode
    MainGui.Add("Text", "xs+14 y+10 w130", "Preview Mode:")
    PreviewModeChoice := MainGui.Add("DropDownList", "x+10 yp-3 w412 Choose1 Disabled", ["start", "switch", "close"])
    PreviewModeChoice.OnEvent("Change", (*) => UpdateCommand())

    MainGui.Add("GroupBox", "xs w580 r4.5 y+16 Section", "3. Generated Command")
    CommandOutputEdit := MainGui.Add("Edit", "xs+14 ys+24 w552 r2.8 ReadOnly -Wrap", "")

    ; Action Buttons
    CopyBtn := MainGui.Add("Button", "xs y+12 w110 Default", "Copy Command")
    CopyInstallDirBtn := MainGui.Add("Button", "x+8 yp w110", "Copy {InstallDir}")
    RunBtn := MainGui.Add("Button", "x+8 yp w95", "Run Command")
    SaveBatBtn := MainGui.Add("Button", "x+8 yp w85", "Save .bat")
    ShortcutBtn := MainGui.Add("Button", "x+8 yp w105", "Create Shortcut")
    ResetBtn := MainGui.Add("Button", "x+8 yp w60", "Reset")

    CopyInstallDirBtn.OnEvent("Click", OnCopyInstallDir)

    CopyBtn.OnEvent("Click", OnCopyCommand)
    RunBtn.OnEvent("Click", OnRunCommand)
    SaveBatBtn.OnEvent("Click", OnSaveBatch)
    ShortcutBtn.OnEvent("Click", OnCreateShortcut)
    ResetBtn.OnEvent("Click", OnResetDefaults)

    ; Status Bar
    StatusBarCtrl := MainGui.Add("StatusBar", , "Ready.")

    MainGui.OnEvent("Close", (*) => ExitApp())
    MainGui.OnEvent("Size", OnGuiSize)

    ; Initial state
    ApplyModeFieldRules(1)
    UpdateCommand()

    MainGui.Show("w612 AutoSize")
}

; ------------------------------------------------------------------------------
; Dynamic Field Rules & Mode Management
; ------------------------------------------------------------------------------
OnModeChange(*) {
    modeIdx := ModeChoice.Value
    ApplyModeFieldRules(modeIdx)
    UpdateCommand()
}

ApplyModeFieldRules(modeIdx) {
    global AccountEdit, AppIdEdit, GameNameEdit, PreviewModeChoice

    ; 1: start (Steam)
    ; 2: start<appid>
    ; 3: start nsg (Non-Steam)
    ; 4: switch
    ; 5: close
    ; 6: preview
    ; 7: watch

    SetControlState(AccountEdit, modeIdx == 1 || modeIdx == 4 || modeIdx == 6)
    SetControlState(AppIdEdit, modeIdx == 1 || modeIdx == 2 || modeIdx == 6)
    SetControlState(GameNameEdit, modeIdx == 1 || modeIdx == 2 || modeIdx == 3 || modeIdx == 6 || modeIdx == 7)
    SetControlState(PreviewModeChoice, modeIdx == 6)
}
SetControlState(ctrl, isEnabled) {
    ctrl.Enabled := isEnabled
}


OnAppIdChange(*) {
    val := Trim(AppIdEdit.Value)
    ; If user pastes "start12345" or "steam://rungameid/12345", clean it up
    if RegExMatch(val, "i)^start(\d+)$", &m) {
        AppIdEdit.Value := m[1]
    } else if RegExMatch(val, "i)rungameid\/(\d+)", &m) {
        AppIdEdit.Value := m[1]
    }
    UpdateCommand()
}

; ------------------------------------------------------------------------------
; Command String Builder
; ------------------------------------------------------------------------------
BuildCommandArgs() {
    global ModeChoice, AccountEdit, AppIdEdit, GameNameEdit, PreviewModeChoice
    modeIdx := ModeChoice.Value
    args := []

    switch modeIdx {
        case 1: ; start <account> <appid> [name]
            account := Trim(AccountEdit.Value)
            appId := Trim(AppIdEdit.Value)
            gameName := Trim(GameNameEdit.Value)

            args.Push("start")
            args.Push(QuoteArg(account != "" ? account : "+s:YOUR_STEAM_ID:0", true))
            args.Push(appId != "" ? appId : "3017860")
            if (gameName != "" && gameName != appId) {
                args.Push(QuoteArg(gameName, true))
            }

        case 2: ; start<appid> [name]
            appId := Trim(AppIdEdit.Value)
            cleanId := RegExReplace(appId, "\D", "")
            if (cleanId == "")
                cleanId := "3017860"
            gameName := Trim(GameNameEdit.Value)

            args.Push("start" . cleanId)
            if (gameName != "" && gameName != cleanId) {
                args.Push(QuoteArg(gameName, true))
            }

        case 3: ; start nsg <game-exe> [name]
            gameTarget := Trim(GameNameEdit.Value)
            args.Push("start")
            args.Push("nsg")
            args.Push(QuoteArg(gameTarget != "" ? gameTarget : "{InstallDir}\game.exe", true))

        case 4: ; switch <account>
            account := Trim(AccountEdit.Value)
            args.Push("switch")
            args.Push(QuoteArg(account != "" ? account : "+s:YOUR_STEAM_ID:0", true))

        case 5: ; close
            args.Push("close")

        case 6: ; preview [mode] [account] [appid] [name]
            prevMode := PreviewModeChoice.Text
            account := Trim(AccountEdit.Value)
            appId := Trim(AppIdEdit.Value)
            gameName := Trim(GameNameEdit.Value)

            args.Push("preview")
            if (gameName != "" && gameName != "Preview Game") {
                args.Push(prevMode != "" ? prevMode : "start")
                args.Push(QuoteArg(account != "" ? account : "+s:YOUR_STEAM_ID:0", true))
                args.Push(appId != "" ? appId : "3017860")
                args.Push(QuoteArg(gameName, true))
            } else if (appId != "" && appId != "3017860") {
                args.Push(prevMode != "" ? prevMode : "start")
                args.Push(QuoteArg(account != "" ? account : "+s:YOUR_STEAM_ID:0", true))
                args.Push(appId)
            } else if (account != "" && account != "+s:YOUR_STEAM_ID:0") {
                args.Push(prevMode != "" ? prevMode : "start")
                args.Push(QuoteArg(account, true))
            } else if (prevMode != "start" && prevMode != "") {
                args.Push(prevMode)
            }

        case 7: ; watch <status-file>
            statusTarget := Trim(GameNameEdit.Value)
            args.Push("watch")
            args.Push(QuoteArg(statusTarget != "" ? statusTarget : "{InstallDir}\sura.status", true))
    }

    return args
}

BuildFullCommandLine() {
    args := BuildCommandArgs()
    
    argStr := ""
    for _, arg in args {
        argStr .= (argStr == "" ? "" : " ") . arg
    }

    return "Sura.exe" . (argStr != "" ? " " . argStr : "")
}

QuoteArg(arg, forceQuotes := false) {
    if (arg == "")
        return '""'
    if forceQuotes || RegExMatch(arg, '[ \t"+:|]') {
        return '"' . StrReplace(arg, '"', '\"') . '"'
    }
    return arg
}

UpdateCommand() {
    global CommandOutputEdit, StatusBarCtrl
    fullCmd := BuildFullCommandLine()
    CommandOutputEdit.Value := fullCmd
}

; ------------------------------------------------------------------------------
; Browse Button Handlers
; ------------------------------------------------------------------------------

OnCopyInstallDir(*) {
    A_Clipboard := "{InstallDir}"
    SetStatus('Copied "{InstallDir}" to clipboard!')
    ToolTip('Copied "{InstallDir}" to clipboard!', , , 1)
    SetTimer(() => ToolTip(, , , 1), -1800)
}

; ------------------------------------------------------------------------------
; Action Handlers: Copy, Run, Save .bat, Create Shortcut, Reset
; ------------------------------------------------------------------------------
OnCopyCommand(*) {
    global CommandOutputEdit, StatusBarCtrl, MainGui
    cmd := CommandOutputEdit.Value
    if (cmd == "") {
        SetStatus("Nothing to copy.", true)
        return
    }

    A_Clipboard := cmd
    SetStatus("Command copied to clipboard!")
    ToolTip("Copied to clipboard!", , , 1)
    SetTimer(() => ToolTip(, , , 1), -1800)
}

OnRunCommand(*) {
    global CommandOutputEdit
    cmd := CommandOutputEdit.Value
    if (cmd == "") {
        SetStatus("No command to run.", true)
        return
    }

    try {
        Run(cmd, A_ScriptDir)
        SetStatus("Command executed successfully.")
    } catch Error as err {
        SetStatus("Execution failed: " . err.Message, true)
        MsgBox("Failed to run command:`n`n" . cmd . "`n`nError: " . err.Message, "Sura Run Error", "Iconx")
    }
}

OnSaveBatch(*) {
    global CommandOutputEdit, GameNameEdit, AppIdEdit, ModeChoice
    cmd := CommandOutputEdit.Value
    if (cmd == "") {
        SetStatus("No command to save.", true)
        return
    }

    modeIdx := ModeChoice.Value
    suggestedName := "launch-"
    nameVal := SanitizeFileName(Trim(GameNameEdit.Value))
    if (nameVal != "")
        suggestedName .= nameVal
    else if ((modeIdx == 1 || modeIdx == 2) && Trim(AppIdEdit.Value) != "")
        suggestedName .= Trim(AppIdEdit.Value)
    else
        suggestedName .= "sura"
    suggestedName .= ".bat"

    savePath := FileSelect("S16", suggestedName, "Save Batch Launcher", "Batch Files (*.bat)")
    if (savePath == "")
        return

    if !RegExMatch(savePath, "i)\.bat$")
        savePath .= ".bat"

    batContent := "@echo off`r`n"
    batContent .= ":: Generated by Sura Command Generator`r`n"
    batContent .= "cd /d `"%~dp0`"`r`n"
    batContent .= cmd . "`r`n"

    try {
        if FileExist(savePath)
            FileDelete(savePath)
        FileAppend(batContent, savePath, "UTF-8")
        SetStatus("Batch file saved: " . savePath)
    } catch Error as err {
        SetStatus("Failed to save batch file: " . err.Message, true)
        MsgBox("Error saving batch file:`n" . err.Message, "Save Error", "Iconx")
    }
}

OnCreateShortcut(*) {
    global CommandOutputEdit
    global GameNameEdit, AppIdEdit, ModeChoice

    cmd := CommandOutputEdit.Value
    if (cmd == "") {
        SetStatus("No command to create shortcut for.", true)
        return
    }

    targetExe := FileExist(A_ScriptDir . "\Sura.exe") ? A_ScriptDir . "\Sura.exe" : "Sura.exe"
    rawArgs := BuildCommandArgs()
    argStr := ""
    for _, arg in rawArgs {
        argStr .= (argStr == "" ? "" : " ") . arg
    }

    modeIdx := ModeChoice.Value
    suggestedName := ""
    nameVal := SanitizeFileName(Trim(GameNameEdit.Value))
    if (nameVal != "")
        suggestedName := nameVal
    else if ((modeIdx == 1 || modeIdx == 2) && Trim(AppIdEdit.Value) != "")
        suggestedName := "Steam Game " . Trim(AppIdEdit.Value)
    else
        suggestedName := "Sura Launcher"
    suggestedName .= ".lnk"

    savePath := FileSelect("S16", suggestedName, "Create Shortcut", "Shortcut Files (*.lnk)")
    if (savePath == "")
        return

    if !RegExMatch(savePath, "i)\.lnk$")
        savePath .= ".lnk"

    try {
        FileCreateShortcut(targetExe, savePath, A_ScriptDir, argStr, "Launch via Sura", , , , )
        SetStatus("Shortcut created: " . savePath)
    } catch Error as err {
        SetStatus("Failed to create shortcut: " . err.Message, true)
        MsgBox("Error creating shortcut:`n" . err.Message, "Shortcut Error", "Iconx")
    }
}

OnResetDefaults(*) {
    global AccountEdit, AppIdEdit, GameNameEdit, ModeChoice
    ModeChoice.Value := 1
    ApplyModeFieldRules(1)

    AccountEdit.Value := "+s:YOUR_STEAM_ID:0"
    AppIdEdit.Value := "3017860"
    GameNameEdit.Value := "My Game"

    UpdateCommand()
    SetStatus("Reset to default settings.")
}

SetStatus(msg, isError := false) {
    global StatusBarCtrl
    if IsObject(StatusBarCtrl) {
        StatusBarCtrl.SetText(msg)
    }
}

SanitizeFileName(name) {
    return RegExReplace(name, '[\\/:*?"<>|]', "")
}

OnGuiSize(guiObj, minMax, width, height) {
    if (minMax == -1) ; Minimized
        return

    ; Responsive width adjustments
    contentWidth := width - 32
    if (contentWidth < 500)
        return
}
