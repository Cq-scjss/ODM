set(_SB_BINARY_DIR "${SB_BINARY_DIR}/pypopsift")

# PyPopsift requires both CUDAToolkit (for popsift's GPU kernels) and pybind11
# (for the Python wrapper). We gate on both — if either is missing, skip the
# external entirely with a clear message. OpenSfM will fall back to CPU SIFT.
#
# To enable:
#   - vcpkg install pybind11:x64-windows  (preferred; CUDA must already be installed)
#   - or pip install pybind11 in the project venv (then -Dpybind11_DIR=...)
#
# Note: vcpkg's `python3` port currently fails to build on MSVC 19.50 / VS 2026
# (v145 toolset). Installing `boost-python` or anything else that pulls python3
# from vcpkg will fail. pybind11 itself is header-only and may install standalone.
find_package(CUDAToolkit 7.0 QUIET)
find_package(pybind11 QUIET CONFIG)

if(CUDAToolkit_FOUND AND pybind11_FOUND)
    ExternalProject_Add(pypopsift
        DEPENDS
        PREFIX            ${_SB_BINARY_DIR}
        TMP_DIR           ${_SB_BINARY_DIR}/tmp
        STAMP_DIR         ${_SB_BINARY_DIR}/stamp
        #--Download step--------------
        DOWNLOAD_DIR      ${SB_DOWNLOAD_DIR}
        GIT_REPOSITORY    https://github.com/OpenDroneMap/pypopsift
        GIT_TAG           fe2d1ccc63877ba315e65f34d2adeadd838b3ac3
        #--Update/Patch step----------
        UPDATE_COMMAND    ""
        PATCH_COMMAND     ${CMAKE_COMMAND} -DPATCH_FILE=${CMAKE_MODULE_PATH}/patches/pypopsift.patch -DWORKING_DIR=<SOURCE_DIR> -P ${CMAKE_MODULE_PATH}/ApplyGitPatch.cmake
        #--Configure step-------------
        SOURCE_DIR        ${SB_SOURCE_DIR}/pypopsift
        CMAKE_ARGS
            -DOUTPUT_DIR=${SB_INSTALL_DIR}/bin/opensfm/opensfm
            -DCMAKE_INSTALL_PREFIX=${SB_INSTALL_DIR}
            # CUDA 13's CCCL headers refuse to compile with MSVC's traditional
            # preprocessor and emit a #error. /Zc:preprocessor switches MSVC to
            # the standard-conforming preprocessor that CCCL requires. Passed to
            # both host (CXX) and CUDA host compiler (-Xcompiler).
            "-DCMAKE_CXX_FLAGS=/Zc:preprocessor"
            "-DCMAKE_CUDA_FLAGS=-Xcompiler /Zc:preprocessor"
            "-DCMAKE_MODULE_LINKER_FLAGS=/NODEFAULTLIB:python${PYTHON_VER_NODOT}t.lib"
            # Force pybind11 to use legacy Python finding (FindPythonLibsNew).
            # pybind11 3.0's modern path (PYBIND11_FINDPYTHON=NEW) misdetects
            # regular Python 3.13 as free-threaded and asks for python313t.lib
            # which doesn't exist. Legacy path uses sysconfig LDVERSION/VERSION
            # (= "313") which produces the correct python313.lib.
            -DPYBIND11_FINDPYTHON=OFF
            -DPYTHON_EXECUTABLE=${PYTHON_EXE_PATH}
            -DPYTHON_INCLUDE_DIR=${SYSTEM_PYTHON_EXTENSION_INCLUDE_DIR}
            -DPYTHON_LIBRARY=${SYSTEM_PYTHON_LIBRARY}
            -DODM_PYTHON_INCLUDE_DIR=${SYSTEM_PYTHON_EXTENSION_INCLUDE_DIR}
            ${WIN32_CMAKE_ARGS}
            ${ARM64_CMAKE_ARGS}
        #--Build step-----------------
        BINARY_DIR        ${_SB_BINARY_DIR}
        #--Install step---------------
        INSTALL_DIR       ${SB_INSTALL_DIR}
        #--Output logging-------------
        LOG_DOWNLOAD      OFF
        LOG_CONFIGURE     OFF
        LOG_BUILD         OFF
        )
else()
    if(NOT CUDAToolkit_FOUND)
        message(STATUS "PyPopsift skipped: CUDAToolkit >= 7.0 not found. OpenSfM will fall back to CPU SIFT.")
    endif()
    if(NOT pybind11_FOUND)
        message(STATUS "PyPopsift skipped: pybind11 not found. OpenSfM will fall back to CPU SIFT.")
    endif()
endif()
