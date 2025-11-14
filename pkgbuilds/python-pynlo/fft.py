# -*- coding: utf-8 -*-
"""
Aliases to fast FFT implementations and associated helper functions.
"""

__all__ = ["fft", "ifft", "rfft", "irfft",
           "fftshift", "ifftshift"]

# %% Imports
from scipy.fft import next_fast_len, fftshift as _fftshift, ifftshift as _ifftshift
from numpy.fft import fft as np_fft, ifft as np_ifft, rfft as np_rfft, irfft as np_irfft

# %% Helper Functions

#---- FFT Shifts
def fftshift(x, axis=-1):
    return _fftshift(x, axes=axis)

def ifftshift(x, axis=-1):
    return _ifftshift(x, axes=axis)

# %% Transforms

#---- FFTs
def fft(x, fsc=1.0, n=None, axis=-1, overwrite_x=False):
    return fsc * np_fft(x, n=n, axis=axis)

def ifft(x, fsc=1.0, n=None, axis=-1, overwrite_x=False):
    return fsc * np_ifft(x, n=n, axis=axis)

#---- Real FFTs
def rfft(x, fsc=1.0, n=None, axis=-1):
    return fsc * np_rfft(x, n=n, axis=axis)

def irfft(x, fsc=1.0, n=None, axis=-1):
    return fsc * np_irfft(x, n=n, axis=axis)
