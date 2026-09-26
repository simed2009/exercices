"""MediaPipe Hands wrapper + gesture detection.

Ports the same gesture logic used in the Finger Board HTML page
(finger extension via tip/pip/mcp distances from the wrist, pinch via
thumb-tip/index-tip distance normalized by hand scale) to Python/MediaPipe's
python solutions API.
"""

import math
from dataclasses import dataclass

import mediapipe as mp

import config

WRIST = 0
THUMB_TIP = 4
INDEX_TIP = 8
INDEX_PIP = 6
INDEX_MCP = 5
MIDDLE_TIP = 12
MIDDLE_PIP = 10
MIDDLE_MCP = 9
RING_TIP = 16
RING_PIP = 14
RING_MCP = 13
PINKY_TIP = 20
PINKY_PIP = 18
PINKY_MCP = 17


@dataclass
class HandGesture:
    detected: bool = False
    # Normalized (0..1) fingertip position, already mirrored so it matches
    # what the user sees in a selfie-view camera preview.
    index_x: float = 0.0
    index_y: float = 0.0
    index_extended: bool = False
    middle_extended: bool = False
    is_pinching: bool = False
    is_open_palm: bool = False
    landmarks: object = None  # raw mediapipe landmark list, for drawing previews


def _dist(a, b):
    return math.hypot(a.x - b.x, a.y - b.y)


def _is_extended(lm, tip_idx, pip_idx, mcp_idx):
    wrist = lm[WRIST]
    return (
        _dist(lm[tip_idx], wrist) > _dist(lm[pip_idx], wrist) * 1.05
        and _dist(lm[tip_idx], wrist) > _dist(lm[mcp_idx], wrist)
    )


class HandTracker:
    def __init__(self):
        self._hands = mp.solutions.hands.Hands(
            max_num_hands=config.MAX_NUM_HANDS,
            model_complexity=config.MODEL_COMPLEXITY,
            min_detection_confidence=config.MIN_DETECTION_CONFIDENCE,
            min_tracking_confidence=config.MIN_TRACKING_CONFIDENCE,
        )

    def close(self):
        self._hands.close()

    def process(self, rgb_frame):
        """rgb_frame: an RGB numpy array (NOT mirrored). Returns a HandGesture."""
        results = self._hands.process(rgb_frame)
        gesture = HandGesture()

        if not results.multi_hand_landmarks:
            return gesture

        lm = results.multi_hand_landmarks[0].landmark
        gesture.detected = True
        gesture.landmarks = lm

        index_ext = _is_extended(lm, INDEX_TIP, INDEX_PIP, INDEX_MCP)
        middle_ext = _is_extended(lm, MIDDLE_TIP, MIDDLE_PIP, MIDDLE_MCP)
        ring_ext = _is_extended(lm, RING_TIP, RING_PIP, RING_MCP)
        pinky_ext = _is_extended(lm, PINKY_TIP, PINKY_PIP, PINKY_MCP)

        hand_scale = _dist(lm[WRIST], lm[MIDDLE_MCP]) or 0.0001
        pinch_dist = _dist(lm[THUMB_TIP], lm[INDEX_TIP]) / hand_scale

        gesture.index_extended = index_ext
        gesture.middle_extended = middle_ext
        gesture.is_pinching = pinch_dist < config.PINCH_RATIO
        gesture.is_open_palm = index_ext and middle_ext and ring_ext and pinky_ext

        # Mirror x so movement matches what the user sees in a selfie preview,
        # matching the original web page's `(1 - lm[8].x)` convention.
        gesture.index_x = 1.0 - lm[INDEX_TIP].x
        gesture.index_y = lm[INDEX_TIP].y

        return gesture
