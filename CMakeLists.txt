cmake_minimum_required(VERSION 3.20)
project(AddLib
        VERSION 0.1
        LANGUAGES CXX)
list(APPEND CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake)

include(CTest)
include(GNUInstallDirs)
include(AddLib)

add_lib(NAME Example
        SOURCES
            include/example/example.hpp
            src/example.cpp
        INCLUDE_DIRS
            include/
        PROPERTIES
            CXX_STANDARD 17
        TESTS
            test/hello_world.cpp)
install_project()

list_project_targets()
list_project_tests()