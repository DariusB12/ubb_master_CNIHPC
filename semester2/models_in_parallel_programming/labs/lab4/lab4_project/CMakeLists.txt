cmake_minimum_required(VERSION 4.1)
set(CMAKE_CUDA_COMPILER "/usr/local/cuda-13/bin/nvcc")

project(lab4_project LANGUAGES C CXX CUDA)

set(CMAKE_CUDA_STANDARD 20)
set(CMAKE_CXX_STANDARD 20)

# 1. Caută pachetul MPI instalat pe sistem
find_package(MPI REQUIRED COMPONENTS C CXX)

add_executable(lab4_project main.cu
        main7a.cu
        main7b.cu
)

set_target_properties(lab4_project PROPERTIES
        CUDA_SEPARABLE_COMPILATION ON)

# 3. Include headerele MPI (mpi.h)
target_include_directories(lab4_project PUBLIC ${MPI_CXX_INCLUDE_DIRS})

# 4. Leagă bibliotecile MPI (linker)
target_link_libraries(lab4_project PUBLIC MPI::MPI_CXX)