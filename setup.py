from setuptools import setup, Extension
from pkg_resources import resource_filename as pkg_file

try:
    from Cython.Build import cythonize
    USE_CYTHON = True
except ImportError:
    USE_CYTHON = False

file_ext = '.pyx' if USE_CYTHON else '.cpp'

ext = Extension(
    'rbi_tree.tree',
    sources=[pkg_file('rbi_tree', 'tree'+file_ext)],
)
if USE_CYTHON:
    setup(ext_modules=cythonize(ext))
else:
    setup(ext_modules=[ext])


