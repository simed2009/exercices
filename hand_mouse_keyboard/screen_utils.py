"""Multi-monitor helpers built on top of `screeninfo`."""

from screeninfo import get_monitors


def list_monitors():
    """Return the list of monitors as reported by the OS (left-to-right order
    is not guaranteed, so callers that care about "second monitor" should
    rely on index order from get_monitors(), which matches OS enumeration).
    """
    return get_monitors()


def pick_target_monitor(preferred_index=None):
    """Pick the monitor the hand-tracked cursor should control.

    If `preferred_index` is given and valid, use it. Otherwise prefer the
    second monitor (index 1) when one exists, falling back to the primary
    (index 0) monitor on single-screen setups.
    """
    monitors = list_monitors()
    if not monitors:
        raise RuntimeError("لم يتم العثور على أي شاشة متصلة (screeninfo لم يُرجع شيئًا).")

    if preferred_index is not None and 0 <= preferred_index < len(monitors):
        return monitors[preferred_index], preferred_index

    if len(monitors) > 1:
        return monitors[1], 1
    return monitors[0], 0


def monitor_bounds(monitor):
    """Return (x, y, width, height) for a screeninfo Monitor object."""
    return monitor.x, monitor.y, monitor.width, monitor.height
