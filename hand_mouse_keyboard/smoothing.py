"""Simple exponential moving average smoothing for jittery landmark coordinates."""


class ExponentialSmoother:
    def __init__(self, alpha=0.45):
        self.alpha = alpha
        self._x = None
        self._y = None

    def reset(self):
        self._x = None
        self._y = None

    def last(self):
        """Last smoothed value, or (0.5, 0.5) if update() was never called."""
        if self._x is None:
            return 0.5, 0.5
        return self._x, self._y

    def update(self, x, y):
        if self._x is None:
            self._x, self._y = x, y
        else:
            a = self.alpha
            self._x = a * x + (1 - a) * self._x
            self._y = a * y + (1 - a) * self._y
        return self._x, self._y
