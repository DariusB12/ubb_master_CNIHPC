cmake_minimum_required(VERSION 3.10) # 4.1 este o versiune foarte nouă, 3.10 e mai sigură pentru servere
project(lab3_project)

set(CMAKE_CXX_STANDARD 20)

# 1. Caută pachetul MPI instalat pe sistem
find_package(MPI REQUIRED)

# 2. Definește executabilul
add_executable(lab3_project main4a.cpp
        main4b.cpp
        main5a.cpp
        main5b.cpp)

# 3. Include headerele MPI (mpi.h)
target_include_directories(lab3_project PUBLIC ${MPI_CXX_INCLUDE_DIRS})

# 4. Leagă bibliotecile MPI (linker)
target_link_libraries(lab3_project PUBLIC MPI::MPI_CXX)