from setuptools import setup, find_packages
import isicle


with open('README.md') as f:
    readme = f.read()

with open('LICENSE') as f:
    license = f.read()

with open('requirements.txt') as f:
    required = f.read().splitlines()
    required = None

pkgs = find_packages(exclude=('examples', 'docs', 'resources'))

setup(
    name='isicle',
    version=isicle.__version__,
    description='ISiCLE: in silico chemical library engine',
    long_description=readme,
    author='Sean M. Colby',
    author_email='sean.colby@pnnl.gov',
    url='https://github.com/pnnl/isicle',
    license=license,
    packages=pkgs,
    install_requires=required,
    entry_points={
        'console_scripts': ['isicle = isicle.isicle:cli']
    },
    package_data={'': ['isicle/rules/ccs_standard.snakefile',
                       'isicle/rules/ccs_lite.snakefile',
                       'isicle/rules/chemshifts.snakefile'
                       ]},
    include_package_data=True
)
