set(_proj_name openmvs)
set(_SB_BINARY_DIR "${SB_BINARY_DIR}/${_proj_name}")

externalproject_add(vcg
    GIT_REPOSITORY  https://github.com/OpenDroneMap/VCG.git
    GIT_TAG         285
    UPDATE_COMMAND  ""
    SOURCE_DIR      ${SB_SOURCE_DIR}/vcg
    CONFIGURE_COMMAND ""
    BUILD_IN_SOURCE 1
    BUILD_COMMAND   ""
    INSTALL_COMMAND ""
)

# NOTE: eigen34 sub-project removed.
# OpenMVS now uses Eigen from vcpkg (eigen3:x64-windows, currently 5.0.1) via
# the toolchain file. OpenMVS's find_package(Eigen3 ...) will resolve to vcpkg
# automatically. This avoids ODR violations when the same translation units
# also pull in Ceres headers (which are compiled against vcpkg's Eigen 5.0.1).
# If Eigen 5.0 turns out to break OpenMVS source compatibility, restore the
# eigen34 sub-project here and pass -DEIGEN3_INCLUDE_DIR=${SB_SOURCE_DIR}/eigen34/
# to the ExternalProject_Add below.

SET(ARM64_CMAKE_ARGS "")

if(${CMAKE_SYSTEM_PROCESSOR} STREQUAL "aarch64" OR ${CMAKE_SYSTEM_PROCESSOR} STREQUAL "arm64")
  SET(ARM64_CMAKE_ARGS -DOpenMVS_USE_SSE=OFF)
endif()

SET(GPU_CMAKE_ARGS "")
if(UNIX)
    if (EXISTS "/usr/local/cuda/lib64/stubs")
        SET(GPU_CMAKE_ARGS -DCMAKE_LIBRARY_PATH=/usr/local/cuda/lib64/stubs)
    endif()
endif()

if(WIN32)
  # On Windows systems without NVIDIA GPUs, OpenMVS will not launch
  # unless a CUDA DLL is available; we download a dummy DLL 
  # generated with https://github.com/ykhwong/dummy-dll-generator that is 
  # loaded UNLESS the real CUDA DLL is available, since it will
  # be loaded before our dummy DLL.
  file(DOWNLOAD "https://github.com/OpenDroneMap/windows-deps/releases/download/2.5.0/nvcuda_dummy.dll" "${SB_INSTALL_DIR}/bin/nvcuda.dll")
endif()

ExternalProject_Add(${_proj_name}
  DEPENDS           ceres opencv vcg
  PREFIX            ${_SB_BINARY_DIR}
  TMP_DIR           ${_SB_BINARY_DIR}/tmp
  STAMP_DIR         ${_SB_BINARY_DIR}/stamp
  #--Download step--------------
  DOWNLOAD_DIR      ${SB_DOWNLOAD_DIR}
  GIT_REPOSITORY    https://github.com/OpenDroneMap/openMVS
  GIT_TAG           355
  #--Update/Patch step----------
  UPDATE_COMMAND    ""
  PATCH_COMMAND     ${CMAKE_COMMAND} -DPATCH_FILE=${CMAKE_MODULE_PATH}/patches/openmvs.patch -DWORKING_DIR=<SOURCE_DIR> -P ${CMAKE_MODULE_PATH}/ApplyGitPatch.cmake
  #--Configure step-------------
  SOURCE_DIR        ${SB_SOURCE_DIR}/${_proj_name}
  CMAKE_ARGS
    -DOpenCV_DIR=${SB_INSTALL_DIR}/lib/cmake/opencv4
    -DVCG_ROOT=${SB_SOURCE_DIR}/vcg
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
    -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL
    -DCMAKE_CUDA_RUNTIME_LIBRARY=Shared
    -DCMAKE_CUDA_ARCHITECTURES=86
    -DCMAKE_INSTALL_PREFIX=${SB_INSTALL_DIR}
    -DOpenMVS_ENABLE_TESTS=OFF
    -DOpenMVS_USE_CERES=ON
    -DOpenMVS_USE_PYTHON=OFF
    -DOpenMVS_USE_BREAKPAD=OFF
    -DOpenMVS_MAX_CUDA_COMPATIBILITY=OFF
    ${GPU_CMAKE_ARGS}
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
