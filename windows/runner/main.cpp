#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

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

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(430, 850);
  if (!window.Create(L"FExpense", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  // Center window on screen taking into account the monitor's work area
  HWND hwnd = window.GetHandle();
  if (hwnd) {
    RECT rect;
    if (::GetWindowRect(hwnd, &rect)) {
      int win_w = rect.right - rect.left;
      int win_h = rect.bottom - rect.top;
      HMONITOR mon = ::MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
      MONITORINFO mi = {sizeof(MONITORINFO)};
      if (::GetMonitorInfo(mon, &mi)) {
        int mon_w = mi.rcWork.right - mi.rcWork.left;
        int mon_h = mi.rcWork.bottom - mi.rcWork.top;
        if (win_h > mon_h - 20) {
          win_h = mon_h - 20;
        }
        int x = mi.rcWork.left + (mon_w - win_w) / 2;
        int y = mi.rcWork.top + (mon_h - win_h) / 2;
        if (y < mi.rcWork.top) {
          y = mi.rcWork.top;
        }
        ::SetWindowPos(hwnd, nullptr, x, y, win_w, win_h,
                       SWP_NOZORDER | SWP_NOACTIVATE);
      }
    }
  }

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
