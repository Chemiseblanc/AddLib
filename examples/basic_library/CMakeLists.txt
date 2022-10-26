cmake_minimum_required(VERSION 3.20)
project(OurLib
        VERSION 1.0
        LANGUAGES CXX)

include(CTest)
include(AddLib)

add_lib(basic_library
    SHARED_AND_STATIC
    DEFAULT_VISIBILITY hidden
    EXPORT_HEADER
        "ourlib/export.h"
    SOURCES
        include/ourlib/ourlib.hpp
        src/ourlib.cpp
    INCLUDE_DIRS
            ${CMAKE_CURRENT_SOURCE_DIR}/include/
    PROPERTIES
        CXX_STANDARD 17
    TESTS
        test/hello_world.cpp
)

install_project()
package_project(
    CONTACT "foo@example.com"
)

addlib_usage()