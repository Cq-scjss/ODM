set(_proj_name pdal-python)
set(_SB_BINARY_DIR "${SB_BINARY_DIR}/${_proj_name}")

if (WIN32)
  # CMake's modern FindPython3 doesn't follow the venv → base_prefix link to
  # locate Development.Module headers/libs on Windows. Pass system Python
  # paths explicitly. NumPy still comes from the venv site-packages.
  set(PP_EXTRA_ARGS -DPython3_EXECUTABLE=${PYTHON_EXE_PATH}
                    -DPython3_ROOT_DIR=${SYSTEM_PYTHON_HOME}
                    -DPython3_FIND_VIRTUALENV=STANDARD
                    -DPython3_INCLUDE_DIR=${SYSTEM_PYTHON_EXTENSION_INCLUDE_DIR}
                    -DPython3_LIBRARY=${SYSTEM_PYTHON_LIBRARY}
                    -DPython3_NumPy_INCLUDE_DIRS=${PYTHON_HOME}/Lib/site-packages/numpy/_core/include
                    -DPYBIND11_FINDPYTHON=OFF
                    -DPYTHON_EXECUTABLE=${PYTHON_EXE_PATH}
                    -DPYTHON_INCLUDE_DIR=${SYSTEM_PYTHON_EXTENSION_INCLUDE_DIR}
                    -DPYTHON_LIBRARY=${SYSTEM_PYTHON_LIBRARY}
                    -DODM_PYTHON_INCLUDE_DIR=${SYSTEM_PYTHON_EXTENSION_INCLUDE_DIR})
  set(PP_CACHE_ARGS -DPython3_ROOT_DIR:PATH=${SYSTEM_PYTHON_HOME}
                    -DPython3_INCLUDE_DIR:PATH=${SYSTEM_PYTHON_EXTENSION_INCLUDE_DIR}
                    -DPython3_LIBRARY:FILEPATH=${SYSTEM_PYTHON_LIBRARY}
                    -DPython3_NumPy_INCLUDE_DIRS:PATH=${PYTHON_HOME}/Lib/site-packages/numpy/_core/include)
else()
  set(PP_EXTRA_ARGS -DPython3_EXECUTABLE=${PYTHON_EXE_PATH}
                    -DPython3_NumPy_INCLUDE_DIRS=${PYTHON_HOME}/lib/python3.12/site-packages/numpy/_core/include)
  set(PP_CACHE_ARGS "")
endif()

ExternalProject_Add(${_proj_name}
  DEPENDS           pdal
  PREFIX            ${_SB_BINARY_DIR}
  TMP_DIR           ${_SB_BINARY_DIR}/tmp
  STAMP_DIR         ${_SB_BINARY_DIR}/stamp
  #--Download step--------------
  DOWNLOAD_DIR      ${SB_DOWNLOAD_DIR}
  GIT_REPOSITORY    https://github.com/PDAL/python
  GIT_TAG           6791a880a87e95f7318e99acfb4a10186379c5dd
  #--Update/Patch step----------
  UPDATE_COMMAND    git submodule update --init --recursive
  PATCH_COMMAND     ${CMAKE_COMMAND} -DPATCH_FILE=${CMAKE_MODULE_PATH}/patches/pdal-python.patch -DWORKING_DIR=<SOURCE_DIR> -DPATCH_APPLIED_FILE=CMakeLists.txt "-DPATCH_APPLIED_PATTERN=only ask FindPython3 for the interpreter and NumPy" -P ${CMAKE_MODULE_PATH}/ApplyGitPatch.cmake
  #--Configure step-------------
  SOURCE_DIR        ${SB_SOURCE_DIR}/${_proj_name}
  CMAKE_ARGS
    -DPDAL_DIR=${SB_INSTALL_DIR}/lib/cmake/PDAL
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
    -DCMAKE_INSTALL_PREFIX:PATH=${SB_INSTALL_DIR}/lib/python${PYTHON_VER_DOT}/dist-packages
    "-DCMAKE_MODULE_LINKER_FLAGS=/NODEFAULTLIB:python${PYTHON_VER_NODOT}t.lib"
    ${WIN32_CMAKE_ARGS}
    ${PP_EXTRA_ARGS}
  CMAKE_CACHE_ARGS
    ${PP_CACHE_ARGS}
  #--Build step-----------------
  BINARY_DIR        ${_SB_BINARY_DIR}
  #--Install step---------------
  INSTALL_DIR       ${SB_INSTALL_DIR}
  INSTALL_COMMAND   ${CMAKE_COMMAND} --build <BINARY_DIR> --config $<CONFIG> --target install
                    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${SB_SOURCE_DIR}/${_proj_name}/src/pdal/__init__.py ${SB_INSTALL_DIR}/lib/python${PYTHON_VER_DOT}/dist-packages/pdal
                    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${SB_SOURCE_DIR}/${_proj_name}/src/pdal/pipeline.py ${SB_INSTALL_DIR}/lib/python${PYTHON_VER_DOT}/dist-packages/pdal
                    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${SB_SOURCE_DIR}/${_proj_name}/src/pdal/drivers.py ${SB_INSTALL_DIR}/lib/python${PYTHON_VER_DOT}/dist-packages/pdal
  #--Output logging-------------
  LOG_DOWNLOAD      OFF
  LOG_CONFIGURE     OFF
  LOG_BUILD         OFF
)
