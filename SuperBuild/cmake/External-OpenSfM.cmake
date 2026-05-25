set(_proj_name opensfm)
set(_SB_BINARY_DIR "${SB_BINARY_DIR}/${_proj_name}")
include(ProcessorCount)
ProcessorCount(nproc)

set(EXTRA_INCLUDE_DIRS "")
if(WIN32)
  set(OpenCV_DIR "${SB_INSTALL_DIR}/x64/vc17/lib")
  set(BUILD_CMD ${CMAKE_COMMAND} --build "${SB_BUILD_DIR}/opensfm" --config "${CMAKE_BUILD_TYPE}")
else()
  set(BUILD_CMD make "-j${nproc}")
  if (APPLE)
    set(OpenCV_DIR "${SB_INSTALL_DIR}")
    set(EXTRA_INCLUDE_DIRS "${HOMEBREW_INSTALL_PREFIX}/include")
  else()
    set(OpenCV_DIR "${SB_INSTALL_DIR}/lib/cmake/opencv4")
  endif()
endif()

ExternalProject_Add(${_proj_name}
  DEPENDS           ceres opencv gflags
  PREFIX            ${_SB_BINARY_DIR}
  TMP_DIR           ${_SB_BINARY_DIR}/tmp
  STAMP_DIR         ${_SB_BINARY_DIR}/stamp
  #--Download step--------------
  DOWNLOAD_DIR      ${SB_DOWNLOAD_DIR}
  GIT_REPOSITORY    https://github.com/OpenDroneMap/OpenSfM/
  GIT_TAG           c5328439465e6ace011f39077d1077d7b1cdd65d
  #--Update/Patch step----------
  UPDATE_COMMAND    git submodule update --init --recursive
  PATCH_COMMAND     ${CMAKE_COMMAND} -DPATCH_FILE=${CMAKE_MODULE_PATH}/patches/opensfm.patch -DWORKING_DIR=<SOURCE_DIR> -P ${CMAKE_MODULE_PATH}/ApplyGitPatch.cmake
  #--Configure step-------------
  SOURCE_DIR        ${SB_INSTALL_DIR}/bin/${_proj_name}
  CONFIGURE_COMMAND ${CMAKE_COMMAND} <SOURCE_DIR>/${_proj_name}/src
    # CERES_ROOT_DIR points to vcpkg's installed dir (was SB_INSTALL_DIR which
    # held ODM's source-built Ceres before the switch to vcpkg). OpenSfM's
    # bundled FindCeres.cmake searches ${CERES_ROOT_DIR}/include and /lib.
    -DCERES_ROOT_DIR=${VCPKG_ROOT}/installed/x64-windows
    -DOpenCV_DIR=${OpenCV_DIR}
    -DADDITIONAL_INCLUDE_DIRS=${SB_INSTALL_DIR}/include
    -DYET_ADDITIONAL_INCLUDE_DIRS=${EXTRA_INCLUDE_DIRS}
    -DSUITESPARSE_INCLUDE_DIR_HINTS=${VCPKG_ROOT}/installed/x64-windows/include/suitesparse
    -DSUITESPARSE_LIBRARY_DIR_HINTS=${VCPKG_ROOT}/installed/x64-windows/lib
    -DOPENSFM_BUILD_TESTS=off
    # Force pybind11 to use legacy Python finding (FindPythonLibsNew). With
    # CMake 3.30+ + CMP0148=NEW, pybind11 picks the modern path which under
    # Python 3.13 resolves PYTHON_LIBRARY to python313t.lib (free-threaded
    # build), which doesn't ship with the regular installer. Legacy path uses
    # sysconfig LDVERSION/VERSION ("313") and produces the correct python313.lib.
    -DPYBIND11_FINDPYTHON=OFF
    -DPYTHON_EXECUTABLE=${PYTHON_EXE_PATH}
    -DPYTHON_INCLUDE_DIR=${SYSTEM_PYTHON_EXTENSION_INCLUDE_DIR}
    -DPYTHON_LIBRARY=${SYSTEM_PYTHON_LIBRARY}
    -DODM_PYTHON_INCLUDE_DIR=${SYSTEM_PYTHON_EXTENSION_INCLUDE_DIR}
    "-DCMAKE_MODULE_LINKER_FLAGS=/NODEFAULTLIB:python${PYTHON_VER_NODOT}t.lib"
    ${WIN32_CMAKE_ARGS}
  BUILD_COMMAND ${BUILD_CMD}
  #--Build step-----------------
  BINARY_DIR        ${_SB_BINARY_DIR}
  #--Install step---------------
  INSTALL_COMMAND    ""
  #--Output logging-------------
  LOG_DOWNLOAD      OFF
  LOG_CONFIGURE     OFF
  LOG_BUILD         OFF
)
