cmake_minimum_required(VERSION 3.18)
project(GPUTucker LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Prefer modern behaviour for find_package hints / *_ROOT variables when available
if(POLICY CMP0074)
  cmake_policy(SET CMP0074 NEW)
endif()
if(POLICY CMP0167)
  cmake_policy(SET CMP0167 NEW)
endif()

# Allow user to override CUDA architectures (default to sm_70)
if(NOT DEFINED CMAKE_CUDA_ARCHITECTURES)
  set(CMAKE_CUDA_ARCHITECTURES 70)
endif()

option(BUILD_SHARED_BOOST "Link against shared Boost libraries if available" ON)

# Allow callers to provide Boost hint variables (useful with Spack):
# -DBOOST_ROOT=/path/to/boost -DBoost_INCLUDE_DIR=/path/to/include -DBoost_LIBRARY_DIR=/path/to/lib
if(DEFINED ENV{BOOST_ROOT} AND NOT DEFINED BOOST_ROOT)
  set(BOOST_ROOT $ENV{BOOST_ROOT})
endif()

find_package(OpenMP REQUIRED)
find_package(CUDAToolkit REQUIRED)

# First try normal find_package for Boost; if that fails and BOOST_ROOT is set, try with HINTS
find_package(Boost 1.65 COMPONENTS program_options filesystem system)
if(NOT Boost_FOUND AND BOOST_ROOT)
  find_package(Boost 1.65 REQUIRED COMPONENTS program_options filesystem system HINTS ${BOOST_ROOT} PATHS ${BOOST_ROOT} ${BOOST_ROOT}/lib ${BOOST_ROOT}/lib64 ${BOOST_ROOT}/include NO_DEFAULT_PATH)
endif()

if(NOT Boost_FOUND)
  message(FATAL_ERROR "Boost (program_options, filesystem, system) not found. Set BOOST_ROOT or pass -DBoost_INCLUDE_DIR and -DBoost_LIBRARY_DIR to CMake.")
endif()

include_directories(${PROJECT_SOURCE_DIR}/include ${PROJECT_SOURCE_DIR}/lib ${Boost_INCLUDE_DIRS})

file(GLOB_RECURSE GPUTUCKER_SOURCES
  "${PROJECT_SOURCE_DIR}/main.cu"
  "${PROJECT_SOURCE_DIR}/source/gputucker/*.cpp"
  "${PROJECT_SOURCE_DIR}/source/common/*.cpp"
)

add_executable(GPUTucker ${GPUTUCKER_SOURCES})

target_include_directories(GPUTucker PRIVATE ${Boost_INCLUDE_DIRS} ${PROJECT_SOURCE_DIR}/include ${PROJECT_SOURCE_DIR}/lib)

# Compile flags similar to the original nvcc command
target_compile_options(GPUTucker PRIVATE
  $<$<COMPILE_LANGUAGE:CXX>:-O2>
  $<$<COMPILE_LANGUAGE:CUDA>:-O2 -Xcompiler=-fopenmp>
)

set_target_properties(GPUTucker PROPERTIES
  CUDA_SEPARABLE_COMPILATION ON
)

target_link_libraries(GPUTucker PRIVATE
  Boost::program_options
  Boost::filesystem
  Boost::system
  OpenMP::OpenMP_CXX
  CUDA::cudart
  CUDA::cublas
  CUDA::curand
)

# Make it easier to run the binary without manually exporting LD_LIBRARY_PATH
set(CMAKE_BUILD_WITH_INSTALL_RPATH OFF)
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH ON)
if(Boost_LIBRARY_DIRS)
  list(APPEND CMAKE_INSTALL_RPATH "${Boost_LIBRARY_DIRS}")
endif()
if(CUDAToolkit_LIBRARY)
  # If CUDAToolkit provides a library location, include it; otherwise rely on system CUDA
  get_filename_component(_cuda_lib_dir ${CUDAToolkit_LIBRARY} DIRECTORY)
  list(APPEND CMAKE_INSTALL_RPATH "${_cuda_lib_dir}")
elseif(DEFINED ENV{CUDA_HOME})
  list(APPEND CMAKE_INSTALL_RPATH "$ENV{CUDA_HOME}/lib64")
endif()

message(STATUS "Configured GPUTucker with Boost include: ${Boost_INCLUDE_DIRS}")
message(STATUS "Configured CMake install RPATH: ${CMAKE_INSTALL_RPATH}")
message(STATUS "CUDAToolkit found: ${CUDAToolkit_VERSION}")
