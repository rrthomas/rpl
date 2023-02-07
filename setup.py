import os
from build_manpages.build_manpages import build_manpages, get_install_cmd, get_build_py_cmd
from setuptools import setup
from setuptools.command.build_py import build_py
from setuptools.command.install import install

# Override build_py command to run help2man
class rpl_build_py(build_py):
    def run(self):
        os.environ['COLUMNS'] = '999'
        self.spawn(['help2man', '--locale=C.UTF-8', '--no-info', '--name="replace strings in files"', '--include=man-include.1', '--output=rpl.1', './rpl'])
        super().run()

# Override build_manpages command to do nothing
class rpl_build_manpages(build_manpages):
    def run(self):
        pass

setup(
    cmdclass={
        'build_manpages': rpl_build_manpages,
        'build_py': get_build_py_cmd(rpl_build_py),
        'install': get_install_cmd(install),
    }
)
