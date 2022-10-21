cmake_minimum_required(VERSION 3.20)
project(AddLib
        VERSION 2.0
        DESCRIPTION "Simplified interfaces for modern target-based workflows")
list(APPEND CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake)

#include(GNUInstallDirs)
#install(DIRECTORY)


option(BUILD_EXAMPLES "Build Example Projects" OFF)
if(BUILD_EXAMPLES)
    include(CTest)
    add_subdirectory(examples)
endif()