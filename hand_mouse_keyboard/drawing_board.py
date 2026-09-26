"""A finger-drawn whiteboard shown on the target (second) monitor.

Same interaction model as the Finger Board HTML reference page: the
index fingertip draws while it's the only extended finger, index+middle
together lifts the pen (move without drawing), and a real mouse click
(delivered by app.py via pyautogui, from a pinch) hits the toolbar
buttons - color swatches, eraser, clear - the same way it hits any other
on-screen button.
"""

import tkinter as tk

import focus_helper

COLORS = ["#1b1e27", "#c1553d", "#3d6b58", "#33608f", "#c99a2e"]
PEN_WIDTH = 5
ERASER_WIDTH = 28


class DrawingBoard:
    def __init__(self, root, monitor_bounds, on_close=None):
        self.root = root
        self.on_close = on_close
        self.mx, self.my, self.mw, self.mh = monitor_bounds
        self.color = COLORS[0]
        self.tool = "pen"  # "pen" | "eraser"
        self._last_point = None  # canvas-local (x, y), or None when the pen is up

        self.win = tk.Toplevel(root)
        self.win.overrideredirect(True)  # keep the WM from stealing focus on click
        self.win.attributes("-topmost", True)
        self.win.geometry(f"{self.mw}x{self.mh}+{self.mx}+{self.my}")
        self.win.configure(bg="white")
        focus_helper.make_window_not_activatable(self.win)

        self._build_ui()
        self.win.withdraw()

    def _build_ui(self):
        toolbar = tk.Frame(self.win, bg="#f6f3ec")
        toolbar.pack(side="top", fill="x")

        def make_btn(text, command):
            b = tk.Button(
                toolbar, text=text, command=command, relief="flat",
                bg="#ffffff", fg="#1b1e27", padx=12, pady=8,
                font=("IBM Plex Sans Arabic", 11), bd=0,
            )
            b.pack(side="left", padx=4, pady=6)
            return b

        self.pen_btn = make_btn("✏️ قلم", lambda: self._set_tool("pen"))
        self.eraser_btn = make_btn("🧽 ممحاة", lambda: self._set_tool("eraser"))

        for c in COLORS:
            sw = tk.Button(
                toolbar, bg=c, activebackground=c, width=2, height=1,
                relief="flat", bd=0, command=lambda c=c: self._set_color(c),
            )
            sw.pack(side="left", padx=3, pady=6)

        make_btn("🗑️ مسح الكل", self.clear)
        make_btn("✕ إخفاء", self.hide)

        self.canvas = tk.Canvas(self.win, bg="white", highlightthickness=0)
        self.canvas.pack(fill="both", expand=True)
        # a real double-click (from a double pinch) anywhere on the board clears it,
        # matching the Finger Board HTML page's behavior.
        self.canvas.bind("<Double-Button-1>", lambda e: self.clear())

    def _set_tool(self, tool):
        self.tool = tool

    def _set_color(self, color):
        self.color = color
        self.tool = "pen"

    def clear(self):
        self.canvas.delete("all")

    def handle_pointer(self, screen_x, screen_y, pen_down):
        """screen_x/screen_y are absolute screen coordinates (same space as
        the pyautogui-driven OS cursor). pen_down=False lifts the pen so the
        next stroke doesn't jump-connect across the gap.
        """
        local_x = screen_x - self.mx
        local_y = screen_y - self.my

        if pen_down:
            if self._last_point is not None:
                width = ERASER_WIDTH if self.tool == "eraser" else PEN_WIDTH
                color = "white" if self.tool == "eraser" else self.color
                self.canvas.create_line(
                    self._last_point[0], self._last_point[1], local_x, local_y,
                    fill=color, width=width, capstyle="round", smooth=True,
                )
            self._last_point = (local_x, local_y)
        else:
            self._last_point = None

    def show(self):
        self.win.deiconify()
        self.win.lift()

    def hide(self):
        self.win.withdraw()
        self._last_point = None
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
