set(_proj_name ceres)
set(_SB_BINARY_DIR "${SB_BINARY_DIR}/${_proj_name}")

if (WIN32)
  # On Windows, Ceres is provided by vcpkg (ceres:x64-windows, currently 2.2.0+).
  # The pinned OpenSfM commit already supports both Ceres 2.0 LocalParameterization
  # and Ceres 2.2+ Manifold APIs via CERES_VERSION_MAJOR/MINOR macros, so the
  # vcpkg-provided Ceres works out of the box. Downstream externals that DEPENDS
  # on `ceres` will get this dummy target satisfied; their own find_package(Ceres
  # CONFIG REQUIRED) picks up vcpkg's CeresConfig.cmake via the toolchain file.
  add_custom_target(${_proj_name})
else()
  ExternalProject_Add(${_proj_name}
    DEPENDS           gflags
    PREFIX            ${_SB_BINARY_DIR}
    TMP_DIR           ${_SB_BINARY_DIR}/tmp
    STAMP_DIR         ${_SB_BINARY_DIR}/stamp
    #--Download step--------------
    DOWNLOAD_DIR      ${SB_DOWNLOAD_DIR}
    URL               http://ceres-solver.org/ceres-solver-2.0.0.tar.gz
    #--Update/Patch step----------
    UPDATE_COMMAND    ""
    PATCH_COMMAND    patch -p1 < ${CMAKE_MODULE_PATH}/ceres.patch
    #--Configure step-------------
    SOURCE_DIR        ${SB_SOURCE_DIR}/${_proj_name}
    CMAKE_ARGS
      -DCMAKE_C_FLAGS=-fPIC
      -DCMAKE_CXX_FLAGS=-fPIC
      -DBUILD_EXAMPLES=OFF
      -DBUILD_TESTING=OFF
      -DMINIGLOG=ON
      -DMINIGLOG_MAX_LOG_LEVEL=-100
      -DCMAKE_INSTALL_PREFIX:PATH=${SB_INSTALL_DIR}
      ${WIN32_CMAKE_ARGS}
    #--Build step-----------------
    BINARY_DIR        ${_SB_BINARY_DIR}
    #--Install step---------------
    INSTALL_DIR       ${SB_INSTALL_DIR}
    #--Output logging-------------
    LOG_DOWNLOAD      OFF
    LOG_CONFIGURE     OFF
    LOG_BUILD         OFF
  )
endif()
