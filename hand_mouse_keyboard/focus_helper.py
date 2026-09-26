"""Best-effort cross-platform helpers to avoid the virtual keyboard stealing
window focus away from whatever application the user is actually typing
into (a text editor, a browser field, etc. on the second monitor).

None of this is bullet proof across every window manager / OS, so
`virtual_keyboard.py` also uses `overrideredirect(True)` on its window,
which is the main defense on Linux/X11 (it keeps the window manager from
ever handing the keyboard window input focus in the first place).
"""

import platform
import subprocess

_SYSTEM = platform.system()


def get_active_window():
    """Return an opaque handle to the currently focused window, or None."""
    try:
        if _SYSTEM == "Linux":
            out = subprocess.run(
                ["xdotool", "getactivewindow"],
                capture_output=True, text=True, timeout=1,
            )
            if out.returncode == 0:
                return out.stdout.strip()
        elif _SYSTEM == "Windows":
            import ctypes
            hwnd = ctypes.windll.user32.GetForegroundWindow()
            return hwnd
    except Exception:
        pass
    return None


def focus_window(handle):
    """Best-effort restore focus to a window handle from get_active_window()."""
    if handle is None:
        return
    try:
        if _SYSTEM == "Linux":
            subprocess.run(["xdotool", "windowactivate", str(handle)], timeout=1)
        elif _SYSTEM == "Windows":
            import ctypes
            ctypes.windll.user32.SetForegroundWindow(handle)
    except Exception:
        pass


def make_window_not_activatable(tk_toplevel):
    """Extra best-effort hint (mainly useful on Windows) so clicking the
    keyboard window doesn't switch OS input focus to it. Safe no-op if the
    underlying platform call isn't available.
    """
    if _SYSTEM == "Windows":
        try:
            import ctypes
            hwnd = ctypes.windll.user32.GetParent(tk_toplevel.winfo_id())
            GWL_EXSTYLE = -20
            WS_EX_NOACTIVATE = 0x08000000
            style = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
            ctypes.windll.user32.SetWindowLongW(hwnd, GWL_EXSTYLE, style | WS_EX_NOACTIVATE)
        except Exception:
            pass
