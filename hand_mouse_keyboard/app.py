"""تحكم باليد: حرّك مؤشر الفأرة على الشاشة الثانية بإصبعك، وانقر واكتب وارسم
بإيماءات يدك أمام الكاميرا - بنفس منطق إيماءات صفحة Finger Board.

الإيماءات:
  - السبابة وحدها ممدودة  -> تحريك المؤشر (أو الرسم إن كانت لوحة الرسم ظاهرة).
  - السبابة + الوسطى معًا  -> تجميد المؤشر / رفع القلم.
  - قرصة سريعة (الإبهام + السبابة) -> نقرة.
  - قرصتان متتاليتان بسرعة -> نقرة مزدوجة (تمسح لوحة الرسم إن كانت ظاهرة).
  - فرد الكف (كل الأصابع ممدودة) لمدة ثانية تقريبًا -> إظهار/إخفاء لوحة المفاتيح.
  - زر "🎨 إظهار/إخفاء لوحة الرسم" في نافذة التحكم -> يفتح لوحة بيضاء على الشاشة
    الهدف يمكنك الرسم عليها بإصبعك، مع أدوات لون/ممحاة/مسح كلي في الأعلى.
"""

import time
import tkinter as tk
from tkinter import ttk

import cv2
import pyautogui
from PIL import Image, ImageTk

import config
import screen_utils
from drawing_board import DrawingBoard
from hand_tracker import HandTracker
from smoothing import ExponentialSmoother
from virtual_keyboard import VirtualKeyboard

pyautogui.FAILSAFE = False


class HandMouseApp:
    def __init__(self, root):
        self.root = root
        self.root.title("تحكم باليد - فأرة ولوحة مفاتيح بالإيماءات")
        self.root.geometry("420x420")
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

        self.cap = None
        self.tracker = None
        self.smoother = ExponentialSmoother(config.SMOOTHING_ALPHA)
        self.running = False
        self.keyboard = None
        self.drawing_board = None

        self.was_pinching = False
        self.last_click_time = 0.0
        self.palm_hold_start = None
        self.last_toggle_time = 0.0

        try:
            self.target_monitor, self.target_index = screen_utils.pick_target_monitor(
                config.TARGET_MONITOR_INDEX
            )
        except RuntimeError as e:
            self.target_monitor, self.target_index = None, None
            self._monitor_error = str(e)
        else:
            self._monitor_error = None

        self._build_ui()

    # ---------------------------------------------------------------- UI --
    def _build_ui(self):
        pad = {"padx": 10, "pady": 6}

        self.video_label = tk.Label(self.root, bg="black")
        self.video_label.pack(padx=10, pady=10)

        info = f"عدد الشاشات: {len(screen_utils.list_monitors())}"
        if self.target_monitor is not None:
            info += f" | الشاشة الهدف: #{self.target_index} ({self.target_monitor.width}x{self.target_monitor.height})"
        else:
            info = self._monitor_error or "تعذر اكتشاف الشاشات"
        self.monitor_label = ttk.Label(self.root, text=info)
        self.monitor_label.pack(**pad)

        self.status_var = tk.StringVar(value="اضغط (بدء) لتشغيل الكاميرا")
        ttk.Label(self.root, textvariable=self.status_var, font=("", 11, "bold")).pack(**pad)

        btns = ttk.Frame(self.root)
        btns.pack(**pad)
        self.start_btn = ttk.Button(btns, text="▶ بدء", command=self.start)
        self.start_btn.grid(row=0, column=0, padx=5)
        self.stop_btn = ttk.Button(btns, text="■ إيقاف", command=self.stop, state="disabled")
        self.stop_btn.grid(row=0, column=1, padx=5)
        self.kb_btn = ttk.Button(btns, text="⌨ إظهار/إخفاء لوحة المفاتيح", command=self.toggle_keyboard, state="disabled")
        self.kb_btn.grid(row=0, column=2, padx=5)
        self.draw_btn = ttk.Button(btns, text="🎨 إظهار/إخفاء لوحة الرسم", command=self.toggle_drawing_board, state="disabled")
        self.draw_btn.grid(row=0, column=3, padx=5)

        hint = (
            "السبابة وحدها = تحريك المؤشر (أو الرسم إذا كانت لوحة الرسم ظاهرة)\n"
            "السبابة + الوسطى = تجميد المؤشر / رفع القلم\n"
            "قرصة سريعة = نقرة | قرصتان = نقرة مزدوجة (تمسح لوحة الرسم إن كانت ظاهرة)\n"
            "فرد الكف لمدة ثانية = إظهار/إخفاء لوحة المفاتيح"
        )
        ttk.Label(self.root, text=hint, foreground="#666", justify="right").pack(**pad)

    # ------------------------------------------------------------- start --
    def start(self):
        if self.running:
            return
        if self.target_monitor is None:
            self.status_var.set(self._monitor_error or "لا توجد شاشة هدف")
            return

        self.cap = cv2.VideoCapture(config.CAMERA_INDEX)
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, config.CAMERA_WIDTH)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, config.CAMERA_HEIGHT)
        if not self.cap.isOpened():
            self.status_var.set("تعذر فتح الكاميرا. تحقق من CAMERA_INDEX في config.py")
            self.cap = None
            return

        self.tracker = HandTracker()
        self.smoother.reset()

        bounds = screen_utils.monitor_bounds(self.target_monitor)
        if self.keyboard is None:
            self.keyboard = VirtualKeyboard(self.root, bounds)
        if self.drawing_board is None:
            self.drawing_board = DrawingBoard(self.root, bounds)

        self.running = True
        self.start_btn.config(state="disabled")
        self.stop_btn.config(state="normal")
        self.kb_btn.config(state="normal")
        self.draw_btn.config(state="normal")
        self.status_var.set("جارٍ البحث عن يد…")
        self._update_frame()

    def stop(self):
        self.running = False
        if self.cap is not None:
            self.cap.release()
            self.cap = None
        if self.tracker is not None:
            self.tracker.close()
            self.tracker = None
        self.start_btn.config(state="normal")
        self.stop_btn.config(state="disabled")
        self.status_var.set("متوقف")

    def toggle_keyboard(self):
        if self.keyboard is not None:
            self.keyboard.toggle()

    def toggle_drawing_board(self):
        if self.drawing_board is not None:
            self.drawing_board.toggle()

    # --------------------------------------------------------------- loop --
    def _update_frame(self):
        if not self.running:
            return

        ok, frame = self.cap.read()
        if ok:
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            gesture = self.tracker.process(rgb)
            self._handle_gesture(gesture)
            self._render_preview(frame, gesture)
        self.root.after(config.FRAME_INTERVAL_MS, self._update_frame)

    def _handle_gesture(self, g):
        now = time.monotonic()

        if not g.detected:
            self.was_pinching = False
            self.palm_hold_start = None
            self.status_var.set("لم يتم اكتشاف يد - ضع يدك أمام الكاميرا")
            return

        mx, my, mw, mh = screen_utils.monitor_bounds(self.target_monitor)
        should_move = g.index_extended and not g.middle_extended

        if should_move:
            sx, sy = self.smoother.update(g.index_x, g.index_y)
            screen_x = max(mx, min(mx + mw - 1, mx + sx * mw))
            screen_y = max(my, min(my + mh - 1, my + sy * mh))
            pyautogui.moveTo(screen_x, screen_y)
        else:
            # keep last smoothed value so there's no jump when movement resumes
            last_x, last_y = self.smoother.last()
            screen_x = mx + last_x * mw
            screen_y = my + last_y * mh

        # --- drawing board: draw while moving, lift the pen otherwise ---
        if self.drawing_board is not None and self.drawing_board.is_visible():
            self.drawing_board.handle_pointer(
                screen_x, screen_y, pen_down=should_move and not g.is_pinching
            )

        # --- pinch => click / double click (rising edge only) ---
        if g.is_pinching and not self.was_pinching:
            if now - self.last_click_time < config.DOUBLE_CLICK_WINDOW_S:
                pyautogui.doubleClick(x=screen_x, y=screen_y)
                self.status_var.set("نقرة مزدوجة 🤏🤏")
                self.last_click_time = 0.0
            else:
                pyautogui.click(x=screen_x, y=screen_y)
                self.status_var.set("نقرة 🤏")
                self.last_click_time = now
        elif not g.is_pinching:
            if should_move:
                self.status_var.set("يتحرك ✋")
            else:
                self.status_var.set("المؤشر مجمّد - إعادة وضع اليد")
        self.was_pinching = g.is_pinching

        # --- open palm hold => toggle virtual keyboard ---
        if g.is_open_palm and not g.is_pinching:
            if self.palm_hold_start is None:
                self.palm_hold_start = now
            elif (now - self.palm_hold_start > config.PALM_HOLD_TOGGLE_S
                  and now - self.last_toggle_time > config.GESTURE_COOLDOWN_S):
                self.toggle_keyboard()
                self.last_toggle_time = now
                self.palm_hold_start = None
        else:
            self.palm_hold_start = None

    def _render_preview(self, frame, gesture):
        preview = cv2.flip(frame, 1)
        h, w = preview.shape[:2]

        if gesture.detected:
            if gesture.is_pinching:
                color = (61, 174, 146)  # accent-2 in BGR-ish
            elif gesture.index_extended and not gesture.middle_extended:
                color = (61, 85, 193)  # accent
            else:
                color = (200, 200, 200)
            px, py = int(gesture.index_x * w), int(gesture.index_y * h)
            cv2.circle(preview, (px, py), 10, color, -1)

        rgb = cv2.cvtColor(preview, cv2.COLOR_BGR2RGB)
        img = ImageTk.PhotoImage(Image.fromarray(rgb))
        self.video_label.imgtk = img  # keep a reference so it isn't garbage-collected
        self.video_label.configure(image=img)

    # -------------------------------------------------------------- close --
    def on_close(self):
        self.stop()
        if self.keyboard is not None:
            self.keyboard.destroy()
        if self.drawing_board is not None:
            self.drawing_board.destroy()
        self.root.destroy()


def main():
    root = tk.Tk()
    HandMouseApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
