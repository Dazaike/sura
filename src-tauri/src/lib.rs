use std::{
    env, fs,
    process::Command,
    thread,
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};

use serde::Serialize;
use tauri::{Emitter, Manager, WebviewWindow};

#[cfg(windows)]
use std::os::windows::process::CommandExt;

#[cfg(windows)]
use std::{ffi::OsStr, iter::once, os::windows::ffi::OsStrExt};

#[cfg(windows)]
use windows_sys::Win32::{
    Foundation::{HWND, LPARAM},
    System::Threading::GetCurrentThreadId,
    UI::Accessibility::{SetWinEventHook, UnhookWinEvent, HWINEVENTHOOK},
    UI::Shell::ShellExecuteW,
    UI::WindowsAndMessaging::{
        DispatchMessageW, EnumWindows, GetClassNameW, GetWindowTextLengthW, GetWindowTextW,
        PeekMessageW, SetWindowPos, ShowWindow, ShowWindowAsync, TranslateMessage,
        EVENT_OBJECT_CREATE, EVENT_OBJECT_SHOW, HWND_BOTTOM, MSG, PM_REMOVE, SWP_HIDEWINDOW,
        SWP_NOACTIVATE, SW_HIDE, SW_SHOWNORMAL, WINEVENT_OUTOFCONTEXT,
    },
};

#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x08000000;

const DEFAULT_CLOSE_ACCOUNT: &str = "+s:YOUR_STEAM_ID:0";
const DEFAULT_KILL_STEAM: &str = r"C:\Path\To\kill-steam.exe";
const TCNO_MAIN_PATH: &str = r"C:\Program Files\TcNo Account Switcher\TcNo-Acc-Switcher_main.exe";

#[derive(Clone, Serialize)]
struct ProgressEvent {
    status: String,
    percent: u8,
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            let window = app
                .get_webview_window("main")
                .expect("main window should exist");
            let args: Vec<String> = env::args().skip(1).collect();

            thread::spawn(move || {
                thread::sleep(Duration::from_millis(350));
                run_cli(window, args);
            });

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

fn run_cli(window: WebviewWindow, args: Vec<String>) {
    emit_progress(&window, "Preparing...", 0);
    thread::sleep(Duration::from_millis(220));

    if args.is_empty() {
        emit_progress(&window, "Ready", 0);
        return;
    }

    match args[0].as_str() {
        "start" => {
            if args.get(1).map(String::as_str) == Some("nsg") {
                if args.len() < 3 {
                    finish_with_usage(&window);
                    return;
                }

                let game_path = &args[2];
                let game_name = args
                    .get(3)
                    .map(String::as_str)
                    .unwrap_or_else(|| default_game_name_from_path(game_path));

                start_non_steam_game(&window, game_path, game_name);
                return;
            }

            if args.len() < 3 {
                finish_with_usage(&window);
                return;
            }

            let account_arguments = &args[1];
            let steam_game_id = &args[2];
            let game_name = args.get(3).map(String::as_str).unwrap_or(steam_game_id);
            let kill_steam_path = args
                .get(4)
                .map(String::as_str)
                .unwrap_or(DEFAULT_KILL_STEAM);

            steam_cli_start(
                &window,
                game_name,
                account_arguments,
                steam_game_id,
                kill_steam_path,
            );
        }
        command if command.starts_with("start") && command.len() > "start".len() => {
            let steam_game_id = &command["start".len()..];
            if !steam_game_id.chars().all(|ch| ch.is_ascii_digit()) {
                finish_with_usage(&window);
                return;
            }

            let game_name = args.get(1).map(String::as_str).unwrap_or(steam_game_id);
            steam_cli_launch_only(&window, game_name, steam_game_id);
        }
        "switch" => {
            if args.len() < 2 {
                finish_with_usage(&window);
                return;
            }

            steam_cli_switch(&window, &args[1]);
        }
        "preview" => {
            let preview_mode = args.get(1).map(String::as_str).unwrap_or("start");
            let account_arguments = args
                .get(2)
                .map(String::as_str)
                .unwrap_or(DEFAULT_CLOSE_ACCOUNT);
            let steam_game_id = args.get(3).map(String::as_str).unwrap_or("3017860");
            let game_name = args.get(4).map(String::as_str).unwrap_or("Preview Game");

            steam_cli_preview(
                &window,
                preview_mode,
                game_name,
                account_arguments,
                steam_game_id,
            );
        }
        "close" => {
            let account_arguments = args
                .get(1)
                .map(String::as_str)
                .unwrap_or(DEFAULT_CLOSE_ACCOUNT);
            let kill_steam_path = args
                .get(2)
                .map(String::as_str)
                .unwrap_or(DEFAULT_KILL_STEAM);
            let extra_kill_list = args.get(3).map(String::as_str).unwrap_or("");
            let game_name = args.get(4).map(String::as_str).unwrap_or("Steam");

            steam_cli_close(
                &window,
                game_name,
                account_arguments,
                kill_steam_path,
                extra_kill_list,
            );
        }
        "watch" => {
            if args.len() < 2 {
                finish_with_usage(&window);
                return;
            }

            watch_status_file(&window, &args[1]);
        }
        _ => finish_with_usage(&window),
    }
}

fn steam_cli_start(
    window: &WebviewWindow,
    game_name: &str,
    account_arguments: &str,
    steam_game_id: &str,
    kill_steam_path: &str,
) {
    emit_progress(window, &format!("Starting {game_name}"), 4);

    if process_exists("steamservice.exe") {
        emit_progress(window, "Closing Steam...", 12);
        run_window_hidden(kill_steam_path, &[]);
        wait_for_process_exit(
            window,
            "steamservice.exe",
            "Closing Steam...",
            12,
            38,
            30_000,
        );
    } else {
        emit_progress(window, "No Steam shutdown needed.", 18);
        loading_wait(window, 500, 18, 34, "Preparing account switch...");
    }

    emit_progress(window, "Switching Steam account...", 42);
    run_tcno(account_arguments);
    loading_wait(window, 1_500, 42, 76, "Switching account...");

    emit_progress(window, "Launching Steam game...", 84);
    start_steam_transient_window_hider(Duration::from_secs(20));
    thread::sleep(Duration::from_millis(75));
    launch_steam_game_silent(steam_game_id);
    wait_for_steam_launch_window(window);
    loading_done(window, "Launch command sent.");
}

fn steam_cli_launch_only(window: &WebviewWindow, game_name: &str, steam_game_id: &str) {
    emit_progress(window, &format!("Starting {game_name}"), 8);
    loading_wait(window, 450, 8, 72, "Preparing launch...");
    emit_progress(window, "Launching Steam game...", 84);
    start_steam_transient_window_hider(Duration::from_secs(20));
    thread::sleep(Duration::from_millis(75));
    launch_steam_game_silent(steam_game_id);
    wait_for_steam_launch_window(window);
    loading_done(window, "Launch command sent.");
}

fn steam_cli_switch(window: &WebviewWindow, account_arguments: &str) {
    emit_progress(window, "Switching Steam account...", 8);
    loading_wait(window, 250, 8, 18, "Preparing account switch...");
    run_tcno(account_arguments);
    loading_wait(window, 1_500, 18, 76, "Switching account...");

    emit_progress(window, "Launching Steam...", 88);
    launch_steam_url("steam://open/main");
    loading_done(window, "Steam launch command sent.");
}

fn steam_cli_close(
    window: &WebviewWindow,
    game_name: &str,
    account_arguments: &str,
    kill_steam_path: &str,
    extra_kill_list: &str,
) {
    emit_progress(window, &format!("Closing {game_name}"), 10);

    run_window_hidden(kill_steam_path, &[]);
    wait_for_process_exit(
        window,
        "steamservice.exe",
        "Closing Steam...",
        10,
        70,
        60_000,
    );

    emit_progress(window, "Switching back to default account...", 76);
    run_tcno(account_arguments);

    if !extra_kill_list.trim().is_empty() {
        emit_progress(window, "Cleaning up extra processes...", 90);
        for process_name in extra_kill_list
            .split('|')
            .map(str::trim)
            .filter(|name| !name.is_empty())
        {
            run_hidden("taskkill", &["/f", "/im", process_name]);
        }
    }

    loading_done(window, "Close flow complete.");
}

fn steam_cli_preview(
    window: &WebviewWindow,
    preview_mode: &str,
    game_name: &str,
    account_arguments: &str,
    steam_game_id: &str,
) {
    match preview_mode {
        "close" => {
            emit_progress(window, &format!("Closing {game_name}"), 10);
            loading_wait(window, 900, 10, 45, "Closing Steam...");
            emit_progress(window, "Switching back to default account...", 76);
            let _ = account_arguments;
            loading_wait(window, 700, 76, 95, "Switching back...");
        }
        "switch" => {
            emit_progress(window, "Switching Steam account...", 8);
            loading_wait(window, 250, 8, 18, "Preparing account switch...");
            let _ = account_arguments;
            loading_wait(window, 900, 18, 76, "Switching account...");
            emit_progress(window, "Launching Steam...", 88);
        }
        _ => {
            emit_progress(window, &format!("Starting {game_name}"), 4);
            emit_progress(window, "Steam is already running.", 12);
            loading_wait(window, 900, 12, 38, "Closing Steam...");
            emit_progress(window, "Switching Steam account...", 42);
            loading_wait(window, 900, 42, 76, "Switching account...");
            let _ = steam_game_id;
            emit_progress(window, "Launching Steam game...", 84);
        }
    }

    loading_done(window, "Preview complete.");
}

fn wait_for_process_exit(
    window: &WebviewWindow,
    process_name: &str,
    message: &str,
    start_percent: u8,
    end_percent: u8,
    timeout_ms: u64,
) {
    let start = Instant::now();
    let timeout = Duration::from_millis(timeout_ms);

    while process_exists(process_name) && start.elapsed() < timeout {
        let elapsed_ms = start.elapsed().as_millis() as u64;
        let progress_span = u64::from(end_percent.saturating_sub(start_percent));
        let percent =
            u64::from(start_percent) + ((progress_span * elapsed_ms.min(timeout_ms)) / timeout_ms);
        emit_progress(window, message, percent.min(100) as u8);
        thread::sleep(Duration::from_millis(500));
    }
}

fn loading_wait(
    window: &WebviewWindow,
    delay_ms: u64,
    start_percent: u8,
    end_percent: u8,
    message: &str,
) {
    if delay_ms == 0 {
        return;
    }

    let steps = 10;
    let step_delay = Duration::from_millis((delay_ms / steps).max(50));

    for step in 1..=steps {
        let percent = start_percent
            + (((end_percent - start_percent) as u16 * step as u16) / steps as u16) as u8;
        emit_progress(window, message, percent);
        thread::sleep(step_delay);
    }
}

fn loading_done(window: &WebviewWindow, message: &str) {
    emit_progress(window, message, 100);
}

fn emit_progress(window: &WebviewWindow, status: &str, percent: u8) {
    let _ = window.emit(
        "progress",
        ProgressEvent {
            status: status.to_string(),
            percent: percent.min(100),
        },
    );
}

fn finish_with_usage(window: &WebviewWindow) {
    emit_progress(
        window,
        "Usage: start<steam_game_id> [game_name] | start <account> <steam_game_id> | start nsg <game_path> [game_name] | watch <status_file> | switch | preview | close",
        100,
    );
}

fn run_tcno(account_arguments: &str) {
    run_window_hidden(TCNO_MAIN_PATH, &[account_arguments]);
}

fn process_exists(process_name: &str) -> bool {
    let output = hidden_command("tasklist")
        .args(["/fi", &format!("imagename eq {process_name}"), "/nh"])
        .output();

    match output {
        Ok(output) if output.status.success() => String::from_utf8_lossy(&output.stdout)
            .to_ascii_lowercase()
            .contains(&process_name.to_ascii_lowercase()),
        _ => false,
    }
}

fn launch_steam_game_silent(steam_game_id: &str) {
    let command = format!("steam://rungameid/{steam_game_id}\" -silent");
    shell_open_exact(&command, false);
}

fn wait_for_steam_launch_window(window: &WebviewWindow) {
    emit_progress(window, "Watching Launching window...", 92);

    while !hide_steam_transient_windows() {
        thread::sleep(Duration::from_millis(25));
    }

    emit_progress(window, "Launching window detected.", 96);

    while hide_steam_transient_windows() {
        thread::sleep(Duration::from_millis(25));
    }

    emit_progress(window, "Launching window closed.", 98);
}

fn launch_steam_url(url: &str) {
    start_process_hidden(url, &[]);
}

fn run_hidden(program: &str, args: &[&str]) {
    let _ = hidden_command(program).args(args).spawn();
}

fn run_window_hidden(program: &str, args: &[&str]) {
    start_process_hidden(program, args);
}

fn start_process_hidden(file_path: &str, args: &[&str]) {
    let mut command = hidden_command("powershell");
    command.args([
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-WindowStyle",
        "Hidden",
        "-Command",
        &start_process_script(file_path, args),
    ]);

    let _ = command.spawn();
}

fn start_process_script(file_path: &str, args: &[&str]) -> String {
    let file_path = ps_quote(file_path);

    if args.is_empty() {
        return format!("Start-Process -FilePath {file_path} -WindowStyle Hidden");
    }

    let arg_list = args
        .iter()
        .map(|arg| windows_arg_quote(arg))
        .collect::<Vec<_>>()
        .join(" ");
    let arg_list = ps_quote(&arg_list);

    format!("Start-Process -FilePath {file_path} -ArgumentList {arg_list} -WindowStyle Hidden")
}

fn ps_quote(value: &str) -> String {
    format!("'{}'", value.replace('\'', "''"))
}

fn windows_arg_quote(value: &str) -> String {
    let escaped = value.replace('\\', "\\\\").replace('"', "\\\"");
    format!("\"{escaped}\"")
}

fn hidden_command(program: &str) -> Command {
    let mut command = Command::new(program);

    #[cfg(windows)]
    command.creation_flags(CREATE_NO_WINDOW);

    command
}

fn start_non_steam_game(window: &WebviewWindow, game_path: &str, game_name: &str) {
    if !std::path::Path::new(game_path).is_file() {
        emit_progress(window, "Game executable not found.", 100);
        return;
    }

    let Some(watcher_script) = find_watcher_script() else {
        emit_progress(window, "Sura watcher script not found.", 100);
        return;
    };

    let status_file = env::temp_dir().join(format!(
        "sura-game-watch-{}-{}.status",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|duration| duration.as_millis())
            .unwrap_or(0)
    ));
    let status_file = status_file.to_string_lossy().to_string();

    let _ = fs::write(&status_file, format!("status=Starting {game_name}\npercent=0\n"));
    emit_progress(window, &format!("Starting {game_name}"), 0);

    let watcher_script = watcher_script.to_string_lossy().to_string();
    start_process_hidden(
        &watcher_script,
        &["--status", &status_file, game_path, game_name],
    );

    watch_status_file(window, &status_file);
}

fn find_watcher_script() -> Option<std::path::PathBuf> {
    let exe_dir = env::current_exe()
        .ok()
        .and_then(|path| path.parent().map(std::path::Path::to_path_buf));
    let current_dir = env::current_dir().ok();

    [exe_dir, current_dir]
        .into_iter()
        .flatten()
        .map(|dir| dir.join("SuraGameWatch.ahk"))
        .find(|path| path.is_file())
}

fn default_game_name_from_path(path: &str) -> &str {
    std::path::Path::new(path)
        .file_stem()
        .and_then(|stem| stem.to_str())
        .filter(|stem| !stem.trim().is_empty())
        .unwrap_or("Non-Steam Game")
}

fn watch_status_file(window: &WebviewWindow, status_file: &str) {
    emit_progress(window, "Waiting for launcher...", 0);

    let start = Instant::now();
    let timeout = Duration::from_secs(10 * 60);
    let mut last_status = String::new();
    let mut last_percent = u8::MAX;

    while start.elapsed() < timeout {
        if let Some((status, percent)) = read_status_file(status_file) {
            if status != last_status || percent != last_percent {
                emit_progress(window, &status, percent);
                last_status = status;
                last_percent = percent;
            }

            if percent >= 100 {
                return;
            }
        }

        thread::sleep(Duration::from_millis(100));
    }

    emit_progress(window, "Window monitor timed out.", 100);
}

fn read_status_file(status_file: &str) -> Option<(String, u8)> {
    let content = fs::read_to_string(status_file).ok()?;
    let mut status = None;
    let mut percent = None;

    for line in content.lines() {
        let Some((key, value)) = line.split_once('=') else {
            continue;
        };

        match key.trim().to_ascii_lowercase().as_str() {
            "status" => status = Some(value.trim().to_string()),
            "percent" => {
                percent = value
                    .trim()
                    .parse::<u8>()
                    .ok()
                    .map(|value| value.min(100));
            }
            _ => {}
        }
    }

    Some((status.unwrap_or_else(|| "Working".to_string()), percent.unwrap_or(0)))
}

#[cfg(windows)]
fn shell_open_exact(target: &str, hidden: bool) {
    let operation = wide_null("open");
    let target = wide_null(target);
    let show = if hidden { SW_HIDE } else { SW_SHOWNORMAL };

    unsafe {
        ShellExecuteW(
            std::ptr::null_mut(),
            operation.as_ptr(),
            target.as_ptr(),
            std::ptr::null(),
            std::ptr::null(),
            show,
        );
    }
}

#[cfg(windows)]
fn wide_null(value: &str) -> Vec<u16> {
    OsStr::new(value).encode_wide().chain(once(0)).collect()
}

#[cfg(windows)]
fn start_steam_transient_window_hider(duration: Duration) {
    thread::spawn(move || {
        let hook = unsafe {
            let _thread_id = GetCurrentThreadId();
            SetWinEventHook(
                EVENT_OBJECT_CREATE,
                EVENT_OBJECT_SHOW,
                std::ptr::null_mut(),
                Some(steam_transient_window_event_hook),
                0,
                0,
                WINEVENT_OUTOFCONTEXT,
            )
        };
        let deadline = Instant::now() + duration;
        while Instant::now() < deadline {
            let _ = hide_steam_transient_windows();

            unsafe {
                let mut msg: MSG = std::mem::zeroed();
                while PeekMessageW(&mut msg, std::ptr::null_mut(), 0, 0, PM_REMOVE) != 0 {
                    TranslateMessage(&msg);
                    DispatchMessageW(&msg);
                }
            }

            thread::sleep(Duration::from_millis(8));
        }

        if !hook.is_null() {
            unsafe {
                UnhookWinEvent(hook);
            }
        }
    });
}

#[cfg(windows)]
unsafe extern "system" fn steam_transient_window_event_hook(
    _hook: HWINEVENTHOOK,
    _event: u32,
    hwnd: HWND,
    _idobject: i32,
    idchild: i32,
    _event_thread: u32,
    _event_time: u32,
) {
    if hwnd.is_null() || idchild != 0 {
        return;
    }

    if unsafe { is_steam_transient_window(hwnd) } {
        unsafe {
            hide_window_aggressively(hwnd);
        }
    }
}

#[cfg(windows)]
#[derive(Default)]
struct SteamTransientWindowScan {
    launching_exists: bool,
}

#[cfg(windows)]
fn hide_steam_transient_windows() -> bool {
    let mut state = SteamTransientWindowScan::default();

    unsafe {
        EnumWindows(
            Some(enum_steam_transient_window),
            &mut state as *mut SteamTransientWindowScan as LPARAM,
        );
    }

    state.launching_exists
}

#[cfg(windows)]
unsafe extern "system" fn enum_steam_transient_window(hwnd: HWND, lparam: LPARAM) -> i32 {
    if unsafe { is_launching_window(hwnd) } {
        unsafe {
            hide_window_aggressively(hwnd);
            (*(lparam as *mut SteamTransientWindowScan)).launching_exists = true;
        }
    }

    if unsafe { is_steam_update_window(hwnd) } {
        unsafe {
            hide_window_aggressively(hwnd);
        }
    }

    1
}

#[cfg(windows)]
unsafe fn is_steam_transient_window(hwnd: HWND) -> bool {
    unsafe { is_launching_window(hwnd) || is_steam_update_window(hwnd) }
}

#[cfg(windows)]
unsafe fn is_launching_window(hwnd: HWND) -> bool {
    let title = unsafe { window_title(hwnd) };
    let class_name = unsafe { window_class_name(hwnd) };
    title == "Launching..."
        || title == "Launching…"
        || (title.to_ascii_lowercase().starts_with("launching") && class_name == "SDL_app")
}

#[cfg(windows)]
unsafe fn is_steam_update_window(hwnd: HWND) -> bool {
    let title = unsafe { window_title(hwnd) };
    let class_name = unsafe { window_class_name(hwnd) };
    title == "Steam" && class_name == "BootstrapUpdateUIClass"
}

#[cfg(windows)]
unsafe fn window_title(hwnd: HWND) -> String {
    let length = unsafe { GetWindowTextLengthW(hwnd) };
    if length <= 0 {
        return String::new();
    }

    let mut buffer = vec![0u16; length as usize + 1];
    let read = unsafe { GetWindowTextW(hwnd, buffer.as_mut_ptr(), buffer.len() as i32) };
    if read <= 0 {
        return String::new();
    }

    String::from_utf16_lossy(&buffer[..read as usize])
}

#[cfg(windows)]
unsafe fn window_class_name(hwnd: HWND) -> String {
    let mut buffer = vec![0u16; 256];
    let read = unsafe { GetClassNameW(hwnd, buffer.as_mut_ptr(), buffer.len() as i32) };
    if read <= 0 {
        return String::new();
    }

    String::from_utf16_lossy(&buffer[..read as usize])
}

#[cfg(windows)]
unsafe fn hide_window_aggressively(hwnd: HWND) {
    unsafe {
        ShowWindow(hwnd, SW_HIDE);
        ShowWindowAsync(hwnd, SW_HIDE);
        SetWindowPos(
            hwnd,
            HWND_BOTTOM,
            -32000,
            -32000,
            1,
            1,
            SWP_HIDEWINDOW | SWP_NOACTIVATE,
        );
    }
}

#[cfg(not(windows))]
fn shell_open_exact(target: &str, _hidden: bool) {
    let _ = Command::new(target).spawn();
}

#[cfg(not(windows))]
fn hide_steam_transient_windows() -> bool {
    false
}
