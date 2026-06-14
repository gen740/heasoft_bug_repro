#!/usr/bin/env python3
"""
Create minimal OGIP-compliant dummy RMF and ARF files for XSPEC fakeit.
Run this from the working directory where XSPEC will be launched.
"""
import numpy as np
from astropy.io import fits


def create_rmf(filename, n=100, emin=0.1, emax=10.0):
    """Diagonal unit response matrix: channel i maps 1:1 to energy bin i."""
    energies = np.linspace(emin, emax, n + 1, dtype=np.float32)
    channels = np.arange(1, n + 1, dtype=np.int16)
    ones_i   = np.ones(n, dtype=np.int16)
    ones_f   = np.ones(n, dtype=np.float32)

    # EBOUNDS: channel number -> energy range
    ebounds = fits.BinTableHDU.from_columns([
        fits.Column('CHANNEL', 'I',              array=channels),
        fits.Column('E_MIN',   'E', unit='keV',  array=energies[:-1]),
        fits.Column('E_MAX',   'E', unit='keV',  array=energies[1:]),
    ])
    ebounds.name = 'EBOUNDS'
    ebounds.header.update(dict(
        HDUCLASS='OGIP', HDUCLAS1='RESPONSE', HDUCLAS2='EBOUNDS',
        HDUVERS='1.3.0', CHANTYPE='PI', DETCHANS=n,
    ))

    # MATRIX: photon energy bin -> detector channel
    # N_GRP=1 / F_CHAN=channel / N_CHAN=1 / MATRIX=1.0 per row (diagonal)
    matrix = fits.BinTableHDU.from_columns([
        fits.Column('ENERG_LO', 'E', unit='keV', array=energies[:-1]),
        fits.Column('ENERG_HI', 'E', unit='keV', array=energies[1:]),
        fits.Column('N_GRP',    'I',              array=ones_i),
        fits.Column('F_CHAN',   'I',              array=channels),
        fits.Column('N_CHAN',   'I',              array=ones_i),
        fits.Column('MATRIX',   'E',              array=ones_f),
    ])
    matrix.name = 'MATRIX'
    matrix.header.update(dict(
        HDUCLASS='OGIP', HDUCLAS1='RESPONSE', HDUCLAS2='RSP_MATRIX',
        HDUVERS='1.3.0', TELESCOP='DUMMY', INSTRUME='DUMMY',
        FILTER='NONE', CHANTYPE='PI', DETCHANS=n, LO_THRES=1e-7,
    ))

    fits.HDUList([fits.PrimaryHDU(), ebounds, matrix]).writeto(filename, overwrite=True)
    print(f'Created {filename}')


def create_arf(filename, n=100, emin=0.1, emax=10.0):
    """Flat unit ARF: effective area = 100 cm^2 across all energies."""
    energies = np.linspace(emin, emax, n + 1, dtype=np.float32)

    specresp = fits.BinTableHDU.from_columns([
        fits.Column('ENERG_LO', 'E', unit='keV',   array=energies[:-1]),
        fits.Column('ENERG_HI', 'E', unit='keV',   array=energies[1:]),
        fits.Column('SPECRESP', 'E', unit='cm**2',
                    array=np.full(n, 100.0, dtype=np.float32)),
    ])
    specresp.name = 'SPECRESP'
    specresp.header.update(dict(
        HDUCLASS='OGIP', HDUCLAS1='RESPONSE', HDUCLAS2='SPECRESP',
        HDUVERS='1.3.0', TELESCOP='DUMMY', INSTRUME='DUMMY', FILTER='NONE',
    ))

    fits.HDUList([fits.PrimaryHDU(), specresp]).writeto(filename, overwrite=True)
    print(f'Created {filename}')


for i in (1, 2):
    create_rmf(f'dummy{i}.rmf')
    create_arf(f'dummy{i}.arf')

print('All response files ready.')
