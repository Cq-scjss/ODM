cmake_minimum_required(VERSION 3.5...3.31)

project(ODM-SuperBuild)

# Setup SuperBuild root location
set(SB_ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR})

if (NOT CMAKE_BUILD_TYPE)
    message(STATUS "No build type selected, default to Release")
    set(CMAKE_BUILD_TYPE "Release")
endif()

if (APPLE)
    find_program(HOMEBREW_EXECUTABLE brew)
    mark_as_advanced(FORCE HOMEBREW_EXECUTABLE)
    if (HOMEBREW_EXECUTABLE)
        # Detected a Homebrew install, query for its install prefix.
        execute_process(COMMAND ${HOMEBREW_EXECUTABLE} --prefix
            OUTPUT_VARIABLE HOMEBREW_INSTALL_PREFIX
            OUTPUT_STRIP_TRAILING_WHITESPACE)
        message(STATUS "Detected Homebrew with install prefix: "
            "${HOMEBREW_INSTALL_PREFIX}, adding to CMake search paths.")
        list(APPEND CMAKE_PREFIX_PATH "${HOMEBREW_INSTALL_PREFIX}")
    endif()

    # Use homebrew's clang compiler since Apple
    # does not allow us to link to libomp
    set(CXX_PATH ${HOMEBREW_INSTALL_PREFIX}/bin/c++-12)
    set(APPLE_CMAKE_ARGS "")
    
    message("Checking for ${CXX_PATH}...")
    if(EXISTS "${CXX_PATH}")
        message("Found Homebrew's C++ compiler: ${CXX_PATH}")
        set(CMAKE_CXX_COMPILER ${CXX_PATH})
        list(APPEND APPLE_CMAKE_ARGS "-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}")
    endif()

    set(C_PATH ${HOMEBREW_INSTALL_PREFIX}/bin/gcc-12)
    message("Checking for ${C_PATH}...")
    if(EXISTS "${C_PATH}")
        message("Found Homebrew's C compiler: ${C_PATH}")
        set(CMAKE_C_COMPILER ${C_PATH})
        list(APPEND APPLE_CMAKE_ARGS "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}")
    endif()

    if (NOT APPLE_CMAKE_ARGS)
        message(WARNING "Cannot find Homebrew's compiler, compilation might fail...")
    endif()
endif()

################################
# Setup SuperBuild directories #
################################

# Setup location where source tar-balls are downloaded
set(SB_DOWNLOAD_DIR "${SB_ROOT_DIR}/download"
    CACHE PATH "Location where source tar-balls are (to be) downloaded.")
mark_as_advanced(SB_DOWNLOAD_DIR)

message(STATUS "SuperBuild files will be downloaded to: ${SB_DOWNLOAD_DIR}")


# Setup location where source tar-balls are located
set(SB_SOURCE_DIR "${SB_ROOT_DIR}/src"
    CACHE PATH "Location where source tar-balls are (will be).")
mark_as_advanced(SB_SOURCE_DIR)
set(SB_BUILD_DIR "${SB_ROOT_DIR}/build")

message(STATUS "SuperBuild source files will be extracted to: ${SB_SOURCE_DIR}")


# Setup location where source tar-balls are located
set(SB_INSTALL_DIR "${SB_ROOT_DIR}/install"
    CACHE PATH "Location where source tar-balls are (will be) installed.")
mark_as_advanced(SB_SOURCE_DIR)

message(STATUS "SuperBuild source files will be installed to: ${SB_INSTALL_DIR}")


# Setup location where binary files are located
set(SB_BINARY_DIR "${SB_ROOT_DIR}/build"
    CACHE PATH "Location where files are (will be) located.")
mark_as_advanced(SB_BINARY_DIR)

message(STATUS "SuperBuild binary files will be located to: ${SB_BINARY_DIR}")

if (WIN32)
    if (NOT DEFINED CMAKE_TOOLCHAIN_FILE)
        message(FATAL_ERROR "CMAKE_TOOLCHAIN_FILE not set. You need to set it to the path of vcpkg.cmake")
    endif()
    get_filename_component(CMAKE_TOOLCHAIN_DIR ${CMAKE_TOOLCHAIN_FILE} DIRECTORY)
    get_filename_component(VCPKG_ROOT "${CMAKE_TOOLCHAIN_DIR}/../../" ABSOLUTE)
    # CMAKE_POLICY_VERSION_MINIMUM=3.5 cascades to all ExternalProjects so that
    # third-party deps with cmake_minimum_required(VERSION < 3.5) (laszip, mve,
    # gflags, lastools, odm_orthophoto, dem2mesh, dem2points, etc.) still
    # configure under modern CMake (4.x dropped support for VERSION < 3.5).
    # CMAKE_FIND_PACKAGE_PREFER_CONFIG=ON makes find_package prefer vcpkg's
    # *Config.cmake files over legacy Find*.cmake modules.
    # EIGEN3_INCLUDE_DIR fallback: vcpkg's Eigen3Config provides only the
    # Eigen3::Eigen target (CONFIG mode) without the legacy variable; some
    # downstream modules still query the variable directly. (Note: OpenMVS
    # itself is patched to derive EIGEN3_INCLUDE_DIR from the imported target;
    # see cmake/patches/openmvs.patch.)
    # CMP0146/CMP0167 = OLD: keep legacy FindCUDA / FindBoost modules available
    # so OpenMVS / PyPopsift's `find_package(CUDA)` and `find_package(Boost)`
    # calls don't error out under CMake 4.x.
    set(WIN32_CMAKE_ARGS
        "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}"
        "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
        "-DCMAKE_POLICY_DEFAULT_CMP0146=OLD"
        "-DCMAKE_POLICY_DEFAULT_CMP0167=OLD"
        "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON"
        "-DEIGEN3_INCLUDE_DIR=${VCPKG_ROOT}/installed/x64-windows/include/eigen3"
    )
    set(PYTHON_HOME "${SB_ROOT_DIR}/../../.venv")
    set(PYTHON_EXE_PATH "${PYTHON_HOME}/Scripts/python")

    # Resolve the system Python install (sys.base_prefix) from the venv.
    # Native extension modules (pypopsift, pdal-python) need the Python C
    # headers and import library which live in the system Python install,
    # not in the venv (which only has python.exe redirecting to base).
    execute_process(
        COMMAND "${PYTHON_EXE_PATH}" -c "import sys, os; print(sys.base_prefix.replace(os.sep, '/'))"
        OUTPUT_VARIABLE SYSTEM_PYTHON_HOME
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    execute_process(
        COMMAND "${PYTHON_EXE_PATH}" -c "import sys; print(f'{sys.version_info.major}{sys.version_info.minor}')"
        OUTPUT_VARIABLE PYTHON_VER_NODOT
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    execute_process(
        COMMAND "${PYTHON_EXE_PATH}" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
        OUTPUT_VARIABLE PYTHON_VER_DOT
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    set(SYSTEM_PYTHON_INCLUDE_DIR "${SYSTEM_PYTHON_HOME}/include")
    set(SYSTEM_PYTHON_LIBRARY     "${SYSTEM_PYTHON_HOME}/libs/python${PYTHON_VER_NODOT}.lib")
    set(SYSTEM_PYTHON_EXTENSION_INCLUDE_DIR "${SYSTEM_PYTHON_INCLUDE_DIR}")
    set(SYSTEM_PYTHON_T_LIBRARY "${SYSTEM_PYTHON_HOME}/libs/python${PYTHON_VER_NODOT}t.lib")
    set(SYSTEM_PYTHON_PYCONFIG "${SYSTEM_PYTHON_INCLUDE_DIR}/pyconfig.h")
    if(EXISTS "${SYSTEM_PYTHON_PYCONFIG}" AND NOT EXISTS "${SYSTEM_PYTHON_T_LIBRARY}")
        file(READ "${SYSTEM_PYTHON_PYCONFIG}" _python_pyconfig)
        string(FIND "${_python_pyconfig}" "#define Py_GIL_DISABLED 1" _python_gil_disabled_index)
        if(NOT _python_gil_disabled_index EQUAL -1)
            set(SYSTEM_PYTHON_EXTENSION_INCLUDE_DIR "${SB_BINARY_DIR}/python${PYTHON_VER_DOT}-include")
            file(REMOVE_RECURSE "${SYSTEM_PYTHON_EXTENSION_INCLUDE_DIR}")
            file(COPY "${SYSTEM_PYTHON_INCLUDE_DIR}/" DESTINATION "${SYSTEM_PYTHON_EXTENSION_INCLUDE_DIR}")
            string(REPLACE "#ifndef Py_GIL_DISABLED\n#define Py_GIL_DISABLED 1\n#endif"
                           "/* Py_GIL_DISABLED intentionally left undefined for python${PYTHON_VER_NODOT}.lib ABI. */"
                           _python_pyconfig "${_python_pyconfig}")
            file(WRITE "${SYSTEM_PYTHON_EXTENSION_INCLUDE_DIR}/pyconfig.h" "${_python_pyconfig}")
            message(STATUS "Using non-free-threaded Python headers: ${SYSTEM_PYTHON_EXTENSION_INCLUDE_DIR}")
        endif()
    endif()
    message(STATUS "System Python: ${SYSTEM_PYTHON_HOME} (lib: python${PYTHON_VER_NODOT})")

    message("Copying VCPKG DLLs...")
    file(GLOB COPY_DLLS "${VCPKG_ROOT}/installed/x64-windows/bin/*.dll")
    file(COPY ${COPY_DLLS} DESTINATION "${SB_INSTALL_DIR}/bin")

    message("Copying CUDA DLLs...")
    file(GLOB CUDA_DLLS "$ENV{CUDA_PATH}/bin/cudart64*.dll")
    file(COPY ${CUDA_DLLS} DESTINATION "${SB_INSTALL_DIR}/bin")

    message("Copying GDAL tools...")
    file(GLOB GDAL_TOOLS "${VCPKG_ROOT}/installed/x64-windows/tools/gdal/*")
    file(COPY ${GDAL_TOOLS} DESTINATION "${SB_INSTALL_DIR}/bin")

    message("Copying GDAL data...")
    file(GLOB GDAL_DATA "${VCPKG_ROOT}/installed/x64-windows/share/gdal/*")
    file(COPY ${GDAL_DATA} DESTINATION "${SB_INSTALL_DIR}/bin/data/gdal")

    message("Copying PROJ data...")
    file(GLOB PROJ_DATA "${VCPKG_ROOT}/installed/x64-windows/share/proj/*")
    file(COPY ${PROJ_DATA} DESTINATION "${SB_INSTALL_DIR}/bin/data/proj")

    # GDAL/OpenCV come from vcpkg; create dummy targets to satisfy `DEPENDS`
    # in downstream externals. Ceres also from vcpkg but its dummy target is
    # created inside External-Ceres.cmake (because find_package(Ceres EXACT
    # 2.0.0) fails against vcpkg's 2.2.0, so External-Ceres.cmake gets
    # included). For GDAL/OpenCV the EXACT versions match vcpkg, so
    # External-{GDAL,OpenCV}.cmake are *not* included by SETUP_EXTERNAL_PROJECT,
    # and we must create the dummy targets here.
    add_custom_target(gdal)
    add_custom_target(opencv)
elseif(APPLE)
    set(PYTHON_HOME "${SB_ROOT_DIR}/../../.venv")
    set(PYTHON_EXE_PATH "${PYTHON_HOME}/bin/python")
else()
    set(PYTHON_HOME "${SB_ROOT_DIR}/../../.venv")
    set(PYTHON_EXE_PATH "${PYTHON_HOME}/bin/python3")
endif()

# Path to additional CMake modules
set(CMAKE_MODULE_PATH ${SB_ROOT_DIR}/cmake)

include(ExternalProject)
include(ExternalProject-Setup)

#########################################
# Download and install third party libs #
#########################################

# ---------------------------------------------------------------------------------------------
# Geospatial Data Abstraction Library (GDAL)
#
set(ODM_GDAL_Version 3.11.1)
option(ODM_BUILD_GDAL "Force to build GDAL library" OFF)

SETUP_EXTERNAL_PROJECT(GDAL ${ODM_GDAL_Version} ${ODM_BUILD_GDAL})

# ---------------------------------------------------------------------------------------------
# Open Source Computer Vision (OpenCV)
#
set(ODM_OpenCV_Version 4.12.0)
option(ODM_BUILD_OpenCV "Force to build OpenCV library" OFF)

SETUP_EXTERNAL_PROJECT(OpenCV ${ODM_OpenCV_Version} ${ODM_BUILD_OpenCV})


# ---------------------------------------------------------------------------------------------
# Google Flags library (GFlags)
#
set(ODM_GFlags_Version 2.2.2)
option(ODM_BUILD_GFlags "Force to build GFlags library" OFF)

SETUP_EXTERNAL_PROJECT(GFlags ${ODM_GFlags_Version} ${ODM_BUILD_GFlags})


# ---------------------------------------------------------------------------------------------
# Ceres Solver
#
set(ODM_Ceres_Version 2.0.0)
option(ODM_BUILD_Ceres "Force to build Ceres library" OFF)

SETUP_EXTERNAL_PROJECT(Ceres ${ODM_Ceres_Version} ${ODM_BUILD_Ceres})


# ---------------------------------------------------------------------------------------------
# Hexer
#
SETUP_EXTERNAL_PROJECT(Hexer 1.5 ON)

# ---------------------------------------------------------------------------------------------
# Open Structure from Motion (OpenSfM)
#

set(custom_libs OpenSfM
				LASzip
				PDAL
				PDALPython
				Untwine
				Entwine
				MvsTexturing
				OpenMVS
				FPCFilter
				PyPopsift
				Obj2Tiles
				OpenPointClass
				ExifTool
				RenderDEM
)

externalproject_add(mve
    GIT_REPOSITORY  https://github.com/OpenDroneMap/mve.git
    GIT_TAG         356
    UPDATE_COMMAND  ""
    SOURCE_DIR      ${SB_SOURCE_DIR}/mve
    CMAKE_ARGS      ${WIN32_CMAKE_ARGS} ${APPLE_CMAKE_ARGS}
    BUILD_IN_SOURCE 1
    INSTALL_COMMAND ""
)

foreach(lib ${custom_libs})
	SETUP_EXTERNAL_PROJECT_CUSTOM(${lib})
endforeach()

include(ProcessorCount)
ProcessorCount(nproc)

if (WIN32)
    set (POISSON_BUILD_CMD ${CMAKE_MAKE_PROGRAM} ${SB_SOURCE_DIR}/PoissonRecon/PoissonRecon.vcxproj /p:configuration=${CMAKE_BUILD_TYPE} /p:Platform=x64 /p:PlatformToolset=${CMAKE_VS_PLATFORM_TOOLSET} /p:WindowsTargetPlatformVersion=${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION})
    set (POISSON_BIN_PATH "x64/${CMAKE_BUILD_TYPE}/PoissonRecon.exe")
else()
    set (POISSON_BUILD_CMD  make -j${nproc} poissonrecon)
    set (POISSON_BIN_PATH "Linux/PoissonRecon")
    if (APPLE)
        set(POISSON_BUILD_CMD COMPILER=${CMAKE_CXX_COMPILER} make -j${nproc} -f Makefile.macos poissonrecon)
    endif()
endif()
externalproject_add(poissonrecon
    GIT_REPOSITORY    https://github.com/OpenDroneMap/PoissonRecon.git
    GIT_TAG           290
    PREFIX            ${SB_BINARY_DIR}/PoissonRecon
    SOURCE_DIR        ${SB_SOURCE_DIR}/PoissonRecon
    UPDATE_COMMAND    ""
    CONFIGURE_COMMAND ""
    BUILD_IN_SOURCE 1
    BUILD_COMMAND    ${POISSON_BUILD_CMD}
    INSTALL_COMMAND  ${CMAKE_COMMAND} -E copy ${SB_SOURCE_DIR}/PoissonRecon/Bin/${POISSON_BIN_PATH} ${SB_INSTALL_DIR}/bin
)

externalproject_add(dem2mesh
    DEPENDS           gdal
    GIT_REPOSITORY    https://github.com/OpenDroneMap/dem2mesh.git
    GIT_TAG           334
    PREFIX            ${SB_BINARY_DIR}/dem2mesh
    SOURCE_DIR        ${SB_SOURCE_DIR}/dem2mesh
    CMAKE_ARGS        -DCMAKE_INSTALL_PREFIX:PATH=${SB_INSTALL_DIR}
                      ${WIN32_CMAKE_ARGS}
                      ${APPLE_CMAKE_ARGS}
)

externalproject_add(dem2points
    DEPENDS           gdal
    GIT_REPOSITORY    https://github.com/OpenDroneMap/dem2points.git
    GIT_TAG           master
    PREFIX            ${SB_BINARY_DIR}/dem2points
    SOURCE_DIR        ${SB_SOURCE_DIR}/dem2points
    CMAKE_ARGS        -DCMAKE_INSTALL_PREFIX:PATH=${SB_INSTALL_DIR}
                      ${WIN32_CMAKE_ARGS}
                      ${APPLE_CMAKE_ARGS}
)

externalproject_add(odm_orthophoto
    DEPENDS           opencv gdal
    GIT_REPOSITORY    https://github.com/OpenDroneMap/odm_orthophoto.git
    GIT_TAG           355
    PREFIX            ${SB_BINARY_DIR}/odm_orthophoto
    SOURCE_DIR        ${SB_SOURCE_DIR}/odm_orthophoto
    PATCH_COMMAND     ${CMAKE_COMMAND} -DPATCH_FILE=${CMAKE_MODULE_PATH}/patches/odm_orthophoto.patch -DWORKING_DIR=<SOURCE_DIR> -DPATCH_APPLIED_FILE=CMakeLists.txt "-DPATCH_APPLIED_PATTERN=include_directories(BEFORE" -P ${CMAKE_MODULE_PATH}/ApplyGitPatch.cmake
    CMAKE_ARGS        -DCMAKE_INSTALL_PREFIX:PATH=${SB_INSTALL_DIR}
                      -DOpenCV_DIR=${VCPKG_ROOT}/installed/x64-windows/share/opencv4
                      ${WIN32_CMAKE_ARGS}
)

externalproject_add(fastrasterfilter
    DEPENDS           gdal
    GIT_REPOSITORY    https://github.com/OpenDroneMap/FastRasterFilter.git
    GIT_TAG           main
    PREFIX            ${SB_BINARY_DIR}/fastrasterfilter
    SOURCE_DIR        ${SB_SOURCE_DIR}/fastrasterfilter
    CMAKE_ARGS        -DCMAKE_INSTALL_PREFIX:PATH=${SB_INSTALL_DIR}
                      ${WIN32_CMAKE_ARGS}
)

externalproject_add(lastools
    GIT_REPOSITORY    https://github.com/OpenDroneMap/LAStools.git
    GIT_TAG           250
    PREFIX            ${SB_BINARY_DIR}/lastools
    SOURCE_DIR        ${SB_SOURCE_DIR}/lastools
    CMAKE_ARGS        -DCMAKE_INSTALL_PREFIX:PATH=${SB_INSTALL_DIR}
                      ${WIN32_CMAKE_ARGS}
)

externalproject_add(draco
    GIT_REPOSITORY    https://github.com/google/draco
    GIT_SHALLOW       OFF
    GIT_TAG           e801aebf9665f6dcf3b6b0a604055a300ff85aa4
    PREFIX            ${SB_BINARY_DIR}/draco
    SOURCE_DIR        ${SB_SOURCE_DIR}/draco
    CMAKE_ARGS        -DDRACO_TRANSCODER_SUPPORTED=ON 
                      -DCMAKE_INSTALL_PREFIX:PATH=${SB_INSTALL_DIR} 
                      ${WIN32_CMAKE_ARGS}
)
