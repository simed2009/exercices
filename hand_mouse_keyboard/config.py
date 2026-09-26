"""Tunable constants for the hand-tracking mouse/keyboard app."""

# --- Camera ---
CAMERA_INDEX = 0
CAMERA_WIDTH = 640
CAMERA_HEIGHT = 480
FRAME_INTERVAL_MS = 15  # ~66 fps polling cap; actual rate is limited by camera/mediapipe

# --- MediaPipe Hands ---
MAX_NUM_HANDS = 1
MODEL_COMPLEXITY = 1
MIN_DETECTION_CONFIDENCE = 0.7
MIN_TRACKING_CONFIDENCE = 0.6

# --- Gestures ---
PINCH_RATIO = 0.42          # (thumb-index distance) / (hand scale) below this = pinching
DOUBLE_CLICK_WINDOW_S = 0.45  # seconds between two pinches to count as a double click
PALM_HOLD_TOGGLE_S = 0.9      # seconds to hold an open palm to toggle the virtual keyboard
GESTURE_COOLDOWN_S = 1.0      # cooldown after a palm-hold toggle before it can fire again

# --- Cursor smoothing ---
SMOOTHING_ALPHA = 0.45  # 0..1, higher = snappier/less smoothing, lower = smoother/more lag

# --- Target monitor ---
# None = auto-pick the second monitor if one exists, otherwise the primary monitor.
TARGET_MONITOR_INDEX = None

# --- Virtual keyboard ---
KEYBOARD_KEY_SIZE = 64
KEYBOARD_KEY_PAD = 6
