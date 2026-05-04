#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <shellapi.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "resource.h"
#include "utils.h"

// Phase 24 — background-mode constants. The runner registers a system
// tray icon when launched with --background so the operator still has a
// way to bring the dashboard up or quit the agent without resorting to
// Task Manager.
namespace {
constexpr UINT kTrayIconCallbackMessage = WM_APP + 1;
constexpr UINT kTrayIconUid = 0x4E57;  // "NW"
constexpr UINT kMenuShowDashboard = 1001;
constexpr UINT kMenuQuit = 1002;
constexpr wchar_t kTrayWindowClassName[] = L"NW_TRAY_HIDDEN";
constexpr wchar_t kTrayTooltip[] = L"NetworkWise — endpoint agent";

// We host the tray icon on its own message-only window so the main
// Flutter window doesn't have to know about it. Stored at file scope
// because the WndProc needs to reach the FlutterWindow and the tray
// helpers without juggling instance pointers.
HWND g_tray_window = nullptr;
NOTIFYICONDATAW g_tray_data{};
FlutterWindow* g_flutter_window = nullptr;

bool HasBackgroundFlag(const std::vector<std::string>& args) {
  for (const auto& a : args) {
    if (a == "--background" || a == "-b") return true;
  }
  return false;
}

void RemoveTrayIcon() {
  if (g_tray_data.cbSize != 0) {
    Shell_NotifyIconW(NIM_DELETE, &g_tray_data);
    g_tray_data = NOTIFYICONDATAW{};
  }
  if (g_tray_window != nullptr) {
    DestroyWindow(g_tray_window);
    g_tray_window = nullptr;
  }
}

void ShowTrayMenu(HWND owner) {
  POINT pt;
  GetCursorPos(&pt);
  HMENU menu = CreatePopupMenu();
  if (menu == nullptr) return;
  AppendMenuW(menu, MF_STRING, kMenuShowDashboard, L"Open dashboard");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kMenuQuit, L"Quit endpoint agent");
  // The owner window must be the foreground window for TrackPopupMenu
  // to behave correctly — without this the menu won't dismiss when
  // the user clicks elsewhere.
  SetForegroundWindow(owner);
  TrackPopupMenu(menu, TPM_RIGHTBUTTON | TPM_BOTTOMALIGN | TPM_LEFTALIGN,
                 pt.x, pt.y, 0, owner, nullptr);
  DestroyMenu(menu);
}

LRESULT CALLBACK TrayWndProc(HWND hwnd, UINT msg, WPARAM wparam,
                             LPARAM lparam) {
  switch (msg) {
    case kTrayIconCallbackMessage:
      if (LOWORD(lparam) == WM_RBUTTONUP || LOWORD(lparam) == WM_CONTEXTMENU) {
        ShowTrayMenu(hwnd);
      } else if (LOWORD(lparam) == WM_LBUTTONDBLCLK) {
        if (g_flutter_window != nullptr) {
          g_flutter_window->Show();
          if (HWND fw = g_flutter_window->GetHandle()) {
            SetForegroundWindow(fw);
          }
        }
      }
      return 0;
    case WM_COMMAND:
      switch (LOWORD(wparam)) {
        case kMenuShowDashboard:
          if (g_flutter_window != nullptr) {
            g_flutter_window->Show();
            if (HWND fw = g_flutter_window->GetHandle()) {
              SetForegroundWindow(fw);
            }
          }
          return 0;
        case kMenuQuit:
          RemoveTrayIcon();
          PostQuitMessage(0);
          return 0;
      }
      break;
    case WM_DESTROY:
      RemoveTrayIcon();
      return 0;
  }
  return DefWindowProc(hwnd, msg, wparam, lparam);
}

bool RegisterTrayWindowClass(HINSTANCE instance) {
  WNDCLASSW wc{};
  wc.lpfnWndProc = TrayWndProc;
  wc.hInstance = instance;
  wc.lpszClassName = kTrayWindowClassName;
  return RegisterClassW(&wc) != 0 ||
         GetLastError() == ERROR_CLASS_ALREADY_EXISTS;
}

bool InstallTrayIcon(HINSTANCE instance) {
  if (!RegisterTrayWindowClass(instance)) return false;
  // HWND_MESSAGE creates a message-only window — invisible, off-screen,
  // doesn't receive paint events. Perfect host for tray callbacks.
  g_tray_window = CreateWindowExW(0, kTrayWindowClassName, L"NW Tray",
                                  0, 0, 0, 0, 0, HWND_MESSAGE, nullptr,
                                  instance, nullptr);
  if (g_tray_window == nullptr) return false;

  g_tray_data.cbSize = sizeof(g_tray_data);
  g_tray_data.hWnd = g_tray_window;
  g_tray_data.uID = kTrayIconUid;
  g_tray_data.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  g_tray_data.uCallbackMessage = kTrayIconCallbackMessage;
  g_tray_data.hIcon =
      LoadIcon(instance, MAKEINTRESOURCE(IDI_APP_ICON));
  wcscpy_s(g_tray_data.szTip, kTrayTooltip);

  if (!Shell_NotifyIconW(NIM_ADD, &g_tray_data)) {
    return false;
  }
  return true;
}
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // Phase 24 — pluck the --background flag before forwarding the rest
  // to the Dart entrypoint. The Dart side can still see it (we forward
  // the original list) so a Settings panel can show a "running hidden"
  // indicator without having to re-detect the flag in C++.
  const bool background_mode = HasBackgroundFlag(command_line_arguments);

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  g_flutter_window = &window;
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"network_wise", origin, size, background_mode)) {
    return EXIT_FAILURE;
  }
  // In background mode closing the window via the X button only hides
  // it instead of quitting the process. The tray icon's "Quit" menu is
  // the only graceful exit path.
  window.SetQuitOnClose(!background_mode);

  if (background_mode) {
    if (!InstallTrayIcon(instance)) {
      // Tray registration failed — fall back to a visible window so
      // the operator can still see the agent. Better than a process
      // they can't reach.
      window.Show();
    }
  }

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  RemoveTrayIcon();
  g_flutter_window = nullptr;
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
