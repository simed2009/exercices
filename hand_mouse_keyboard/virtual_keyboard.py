"""An on-screen keyboard shown on the target (second) monitor.

The user "presses" a key the same way they click anything else: by
pinching while the tracked cursor is hovering over that key. Since the
real OS mouse cursor is what moves (via pyautogui in app.py), a pinch over
a key button triggers this window's normal Tkinter button click - no
separate hit-testing is needed.
"""

import tkinter as tk

import config
import focus_helper

ROWS = [
    list("1234567890"),
    list("QWERTYUIOP"),
    list("ASDFGHJKL"),
    list("ZXCVBNM"),
]

SPECIAL_KEYS = {
    "space": ("مسافة", 6),
    "backspace": ("⌫ حذف", 2),
    "enter": ("⏎ إدخال", 2),
    "shift": ("⇧ Shift", 2),
    "close": ("✕ إغلاق", 1),
}


class VirtualKeyboard:
    def __init__(self, root, monitor_bounds, on_close=None):
        self.root = root
        self.on_close = on_close
        self._shift = False
        self._saved_focus = None

        x, y, w, h = monitor_bounds
        key = config.KEYBOARD_KEY_SIZE
        pad = config.KEYBOARD_KEY_PAD
        kb_w = min(w - 40, (key + pad) * 11)
        kb_h = (key + pad) * (len(ROWS) + 1) + 40

        self.win = tk.Toplevel(root)
        self.win.overrideredirect(True)  # keep the WM from ever focusing this window
        self.win.attributes("-topmost", True)
        try:
            self.win.attributes("-alpha", 0.96)
        except tk.TclError:
            pass
        kb_x = x + (w - kb_w) // 2
        kb_y = y + h - kb_h - 20
        self.win.geometry(f"{int(kb_w)}x{int(kb_h)}+{int(kb_x)}+{int(kb_y)}")
        self.win.configure(bg="#1d1f26")
        focus_helper.make_window_not_activatable(self.win)

        self._build_keys(key, pad)
        self.win.withdraw()

    def _make_key(self, parent, label, width_chars, command):
        btn = tk.Button(
            parent, text=label, width=width_chars, height=2,
            bg="#2a2d38", fg="#e9e6dd", activebackground="#c1553d",
            activeforeground="#ffffff", relief="flat", bd=0,
            font=("IBM Plex Sans Arabic", 12, "bold"),
            command=command,
        )
        return btn

    def _build_keys(self, key, pad):
        container = tk.Frame(self.win, bg="#1d1f26")
        container.pack(expand=True, fill="both", padx=10, pady=10)

        for row in ROWS:
            row_frame = tk.Frame(container, bg="#1d1f26")
            row_frame.pack(pady=pad // 2)
            for ch in row:
                btn = self._make_key(row_frame, ch, 3, lambda c=ch: self._press_char(c))
                btn.pack(side="left", padx=pad // 2)

        bottom = tk.Frame(container, bg="#1d1f26")
        bottom.pack(pady=pad)

        def add_special(name):
            label, w = SPECIAL_KEYS[name]
            cmd = {
                "space": lambda: self._press_special("space"),
                "backspace": lambda: self._press_special("backspace"),
                "enter": lambda: self._press_special("enter"),
                "shift": self._toggle_shift,
                "close": self.hide,
            }[name]
            btn = self._make_key(bottom, label, w * 3, cmd)
            btn.pack(side="left", padx=pad // 2)

        for name in ("shift", "space", "backspace", "enter", "close"):
            add_special(name)

    def _toggle_shift(self):
        self._shift = not self._shift

    def _restore_target_focus(self):
        focus_helper.focus_window(self._saved_focus)

    def _press_char(self, ch):
        import pyautogui
        self._restore_target_focus()
        char = ch.upper() if self._shift else ch.lower()
        pyautogui.write(char)
        if self._shift:
            self._shift = False

    def _press_special(self, name):
        import pyautogui
        self._restore_target_focus()
        pyautogui.press(name)

    def show(self):
        self._saved_focus = focus_helper.get_active_window()
        self.win.deiconify()
        self.win.lift()

    def hide(self):
        self.win.withdraw()
        if self.on_close:
            self.on_close()

    def toggle(self):
        if self.win.state() == "withdrawn":
            self.show()
        else:
            self.hide()

    def is_visible(self):
        return self.win.state() != "withdrawn"

    def destroy(self):
        self.win.destroy()
