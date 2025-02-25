.. _adflow_install:

Installation
============
All the core computations in ``ADflow`` are coded in Fortran.
It is therefore necessary to build this library before using ``ADflow``.

Requirements
------------
See :ref:`install3rdPartyPackages` for details on installing required 3rd party packages.

Building
--------
ADflow follows the standard MDO Lab build procedure.
To start, find a configuration file close to your current setup in::

    $ config/defaults

and copy it to ''config/config.mk''. For example::

    $ cp config/defaults/config.LINUX_GFORTRAN.mk config/config.mk

If you are a beginner user installing the packages on a linux desktop, 
you should use the ``config.LINUX_GFORTRAN`` versions of the configuration 
files. The ``config.LINUX_INTEL`` versions are usually used on clusters.
ADflow has been successfully compiled on LINUX with either
ifort or gfortran.

Once you have copied the config file, compile ADflow by running::

    $ make

If everything was successful, the following lines will be printed to
the screen (near the end)::

   Testing if module adflow can be imported...
   Module adflow was successfully imported.

If you don't see this, it will be necessary to configure the build
manually. To configure manually, open ``config/config.mk`` and modify options as necessary.

It is most likely that you need to modify the ``CGNS_INCLUDE_FLAGS`` and the ``CGNS_LINKER_FLAGS`` variables.
It is also necessary to have``PETSc`` already compiled. 
After changes to the configuration file, run ``make clean`` before attempting a new build.

Verification
------------
ADflow contains a set of simple tests that can be run automatically
to ensure ADflow reproduces the expected reference results. You should
a diff-viewer installed. xxdiff is used by default which can be installed
using::

    $ sudo apt-get install xxdiff

Change to the regression tests directory at::

    $ cd python/reg_tests/

Command line arguemnts for run_reg_tests.py can be found by running::

    $ python run_reg_tests.py --help

To run all regression tests, now simply run::

    $ python run_reg_tests.py

If the tests are successful a 'adflow: Success!' message
will be printed, otherwise a diff window will appear hihglighting
the differences between the reference case and the most recently
completed verification run.

Complex Build
-------------
ADflow contains scripts to automatically build a "complexified"
version of ADflow directly from the real version.

ADflow_CS REQUIRES a complex build of petsc to build and run. The
petsc configuration script must be re-run with the following
options::

    $ ./configure --with-shared-libraries --download-superlu_dist=yes --download-parmetis=yes --download-metis=yes --with-fortran-interfaces=1 --with-debuggig=yes --with-scalar-type=complex --PETSC_ARCH=complex-debug

Follow instructions as before to complete complex build.

Now, to build complex ADflow do::

    $ export PETSC_ARCH=complex-debug
    $ make -f Makefile_CS

Note that the correct, complex PETSC_ARCH MUST be set before the code is
compiled and also must be set when running in complex mode.
