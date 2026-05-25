set(_proj_name openpointclass)
set(_SB_BINARY_DIR "${SB_BINARY_DIR}/${_proj_name}")

ExternalProject_Add(${_proj_name}
  DEPENDS           pdal
  PREFIX            ${_SB_BINARY_DIR}
  TMP_DIR           ${_SB_BINARY_DIR}/tmp
  STAMP_DIR         ${_SB_BINARY_DIR}/stamp
  #--Download step--------------
  DOWNLOAD_DIR      ${SB_DOWNLOAD_DIR}
  GIT_REPOSITORY    https://github.com/uav4geo/OpenPointClass
  GIT_TAG           dd6a560a1d43cb709f7b220b19a436e25a889e3e
  #--Update/Patch step----------
  UPDATE_COMMAND    ""
  #--Configure step-------------
  SOURCE_DIR        ${SB_SOURCE_DIR}/${_proj_name}
  CMAKE_ARGS
    -DPDAL_DIR=${SB_INSTALL_DIR}/lib/cmake/PDAL
    # WITH_GBT=OFF: LightGBM is a deep git submodule that fails to clone behind
    # restrictive networks. The Random Forest classifier (default) still works
    # without GBT. Re-enable when network is friendlier or set up git proxy.
    -DWITH_GBT=OFF
    -DBUILD_PCTRAIN=OFF
    # NOTE: EIGEN3_INCLUDE_DIR removed; OpenPointClass picks up Eigen from
    # vcpkg (5.0.1) via the toolchain file. See comment in External-OpenMVS.cmake.
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
    -DCMAKE_INSTALL_PREFIX:PATH=${SB_INSTALL_DIR}
    ${WIN32_CMAKE_ARGS}
  CMAKE_CACHE_ARGS
    -DWITH_GBT:BOOL=OFF
    -DBUILD_PCTRAIN:BOOL=OFF
  #--Build step-----------------
  BINARY_DIR        ${_SB_BINARY_DIR}
  #--Install step---------------
  INSTALL_DIR       ${SB_INSTALL_DIR}
  #--Output logging-------------
  LOG_DOWNLOAD      OFF
  LOG_CONFIGURE     OFF
  LOG_BUILD         OFF
)
