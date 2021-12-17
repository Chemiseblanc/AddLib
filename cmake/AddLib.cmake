# =====================================================================
# AddLib.cmake - Modern CMake Simplified.
# Version 1.0.0
# Copyright 2021 Matthew Gibson <matt@mgibson.ca>. All Rights Reserved.
# =====================================================================
# Table of Contents:
# 1     - Target Creation
# 1.1     - function(add_lib)
# 1.1.1     - macro(COMMON_TARGET_DEFS)
# 1.1.2     - Test creation
# 1.1.3     - Target definition
# 1.2     - function(add_exe)
# 2     - function(install_project)
# 3     - Registration and Listing
# 3.1     - Target Registration
# 3.1.1     - function(register_target)
# 3.1.1     - function(list_targets)
# 3.1.2     - function(list_project_targets)
# 3.2     - Test Registration
# 3.2.1     - function(register_test)
# 3.2.2     - function(list_tests)
# 3.2.3     - function(list_project_tests)
include_guard(GLOBAL)
message(NOTICE "===========================================================")
message(NOTICE "=== Using AddLib.cmake v1.0.0 - Modern CMake Simplified ===")
message(NOTICE "===========================================================")

# [1] Target Creation
function(add_lib) # [1.1]
    # A shortcut for the boilerplate required to define a library target
    # by default creates static and shared library variants with the naming convention
    # ${PROJECT_NAME}::${NAME}(_static)
    # Header-only and dynamically loadable libraries can be created as options.
    # See the following keyword definitions for a list and description of the options
    include(CMakeParseArguments)
    set(noValues
            STATIC_ONLY         # Create target as a strictly static library
            SHARED_ONLY         # Create target as a strictly shared library
            HEADER_ONLY         # Create target as a header-only library
            MODULE              # Created target as a dynamically loaded library
            RELAXED             # Turn off extra compiler warnings and do not treat them as errors
            EXPORT_ALL_SYMBOLS  # Don't generate an export header and set symbol visibility to visible
            NO_INSTALL          # Don't include the target when installing the project
            HIDDEN              # Don't register any generated targets for listing
            )
    set(singleValues
            NAME            # Target name
            TEST_FRAMEWORK  # Name of testing framework to integrate with.
                            # Supported values are: Catch2, GTest, BoostTest
            COMPONENT       # Add this target to a component which can be specified in find_package
            )
    set(multiValues
            SOURCES GLOB_SOURCES                            # Source file list or glob expressions
            INCLUDE_DIRS PRIVATE_INCLUDE_DIRS               # include directories for target
            LINK PRIVATE_LINK                               # Targets to link against
            PROPERTIES                                      # Target properties
            FLAGS PRIVATE_FLAGS                             # Manually specified compile flags for target
            PRECOMPILE_HEADERS PRIVATE_PRECOMPILE_HEADERS   # List of headers to precompile
            TESTS GLOB_TESTS                                # Test file list or glob expressions
            TEST_LINK_TARGETS                               # Additional targets to link to tests
            DEPENDS_ON                                      # Required components in this or other packages
            )
    cmake_parse_arguments(ARG "${noValues}" "${singleValues}" "${multiValues}" ${ARGN})

    # Check preconditions
    if(ARG_KEYWORDS_MISSING_VALUES)
        message(WARNING "No values found for arguments ${ARG_KEYWORDS_MISSING_VALUES}")
    endif()
    if(ARG_UNPARSED_ARGUMENTS)
        message(WARNING "Unused arguments ${ARG_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT ARG_NAME)
        message(FATAL_ERROR "library must be given a name")
    endif()

    # Compile flags for strict mode.
    # This is enabled by default unless add_lib is given RELAXED as an argument
    if(UNIX)
        set(STRICT_FLAGS -Wall -Wextra -Werror -pedantic)
    elseif(WIN32)
    endif()

    # Process Include directories for build and install configs
    foreach(path IN LISTS ARG_INCLUDE_DIRS)
        cmake_path(IS_PREFIX CMAKE_CURRENT_SOURCE_DIR ${path} NORMALIZE prefixed)
        if(${prefixed})
            list(APPEND ARG_BUILD_INCLUDE_DIRS ${path})
        else()
            list(APPEND ARG_BUILD_INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/${path}")
        endif()
    endforeach()
    set(ARG_INCLUDE_DIRS ${ARG_BUILD_INCLUDE_DIRS})
    unset(ARG_BUILD_INCLUDE_DIRS)

    macro(COMMON_TARGET_DEFS) # [1.1.1]
        # Common library target definitions.
        add_library(${target_alias} ALIAS ${target_name})
        set_target_properties(${target_name}
                PROPERTIES EXPORT_NAME ${ARG_NAME})
        list(APPEND install_targets ${target_name})

        if(NOT ARG_HIDDEN)
            register_target(${target_alias})
        endif()

        if(ARG_HEADER_ONLY)
            set(PUBLIC_KEYWORD INTERFACE)
            set(PRIVATE_KEYWORD INTERFACE)
        else()
            set(PUBLIC_KEYWORD PUBLIC)
            set(PRIVATE_KEYWORD PRIVATE)
        endif()

        if (ARG_EXPORT_ALL_SYMBOLS)
            list(APPEND ARG_PROPERTIES
                    C_VISIBILITY_PRESET visible
                    CXX_VISIBILITY_PRESET visible
                    VISIBILITY_INLINES_HIDDEN NO)
        else()
            if (NOT (ARG_STATIC_ONLY OR ARG_HEADER_ONLY))
                include(GenerateExportHeader)
                generate_export_header(${target_name} BASE_NAME ${PROJECT_NAME})
                target_include_directories(${target_name}
                        ${PUBLIC_KEYWORD}
                            $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>)
                list(APPEND ARG_PROPERTIES
                        C_VISIBILITY_PRESET hidden
                        CXX_VISIBILITY_PRESET hidden
                        VISIBILITY_INLINES_HIDDEN YES)
            endif()
        endif()

        # If glob expressions for source files are present, it processes them and appends to the source list.
        # Also prints a warning since globing is not recommended for large projects.
        if (ARG_GLOB_SOURCES)
            message(STATUS "Globbing sources for ${target_name}. This may increase configure times.")
            file(GLOB ${target_name}_GLOB_SOURCES CONFIGURE_DEPENDS ${ARG_GLOB_SOURCES})
            list(APPEND ${ARG_SOURCES} ${target_name}_GLOB_SOURCES)
        endif()

        target_sources(${target_name}
                PRIVATE
                    ${ARG_SOURCES})
        target_include_directories(${target_name}
                ${PUBLIC_KEYWORD}
                    $<BUILD_INTERFACE:${ARG_INCLUDE_DIRS}>
                    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
                ${PRIVATE_KEYWORD}
                    ${ARG_PRIVATE_INCLUDE_DIRS})
        target_link_libraries(${target_name}
                ${PUBLIC_KEYWORD}
                    ${ARG_LINK}
                ${PRIVATE_KEYWORD}
                    ${ARG_PRIVATE_LINK})
        if(ARG_PROPERTIES)
            set_target_properties(${target_name}
                PROPERTIES
                    ${ARG_PROPERTIES})
        endif()
        target_compile_options(${target_name}
                ${PUBLIC_KEYWORD}
                    ${ARG_FLAGS}
                ${PRIVATE_KEYWORD}
                    ${ARG_PRIVATE_FLAGS}
                    $<$<NOT:$<BOOL:${ARG_RELAXED}>>:${STRICT_FLAGS}>)
        target_precompile_headers(${target_name}
                ${PUBLIC_KEYWORD}
                    ${ARG_PRECOMPILE_HEADERS}
                ${PRIVATE_KEYWORD}
                    ${ARG_PRIVATE_PRECOMPILE_HEADERS})

        # Generates the boilerplate for setting up tests for a target and integrating them with CTest.
        # If a supported testing framework is supplied it creates a single test target for that framework,
        # generating a source file with the testing main() if necessary.
        if (BUILD_TESTING) # [1.1.2]
            if (ARG_GLOB_TESTS)
                message(STATUS "Globbing sources for ${target_name} tests. This may increase configure times.")
                file(GLOB ${target_name}_GLOB_SOURCES CONFIGURE_DEPENDS ${ARG_GLOB_TESTS})
                list(APPEND ${ARG_TESTS} ${target_name}_GLOB_SOURCES)
            endif()
            if(ARG_TESTS)
                if(ARG_TEST_FRAMEWORK)
                    if(${ARG_TEST_FRAMEWORK} STREQUAL Catch2)
                        # Catch2
                        include(Catch)
                        if(TARGET Catch2::Catch2WithMain)
                        else()
                        endif()
                    elseif(${ARG_TEST_FRAMEWORK} STREQUAL GTest)
                        # Google Test
                        include(GoogleTest)
                    elseif(${ARG_TEST_FRAMEWORK} STREQUAL BoostTest)
                        # Boost.Test
                        include(BoostTestTargets)
                    else()
                        message(FATAL_ERROR "Unsupported test framework ${ARG_TEST_FRAMEWORK}.")
                    endif()
                else()
                    foreach(TEST_SRC IN LISTS ARG_TESTS)
                        cmake_path(GET TEST_SRC STEM TEST)
                        set(test_target ${target_name}_${TEST})
                        add_executable(${test_target} ${TEST_SRC})
                        target_link_libraries(${test_target}
                                PRIVATE
                                ${target_name})
                        add_test(NAME ${test_target} COMMAND ${test_target})
                        if(NOT ARG_HIDDEN)
                            register_test(${test_target})
                        endif()
                    endforeach()
                endif()
            endif()
        endif()
    endmacro()

    # [1.1.3] Target definition
    # Allowed target types are listed below as mutually exclusive for targets on different lines,
    # and mutually inclusive for targets on the same line.
    # Target Types:
    # - Header-Only Library
    # - Dynamically Loadable Library
    # - Static Library, Shared Library
    if(ARG_HEADER_ONLY)
        # Header-Only Library Definition
        set(target_name ${PROJECT_NAME}_${ARG_NAME})
        set(target_alias ${PROJECT_NAME}::${ARG_NAME})
        add_library(${target_name} INTERFACE)
        COMMON_TARGET_DEFS()
    elseif(ARG_MODULE)
        # Module (Dynamically loadable library)
        set(target_name ${PROJECT_NAME}_${ARG_NAME})
        set(target_alias ${PROJECT_NAME}::${ARG_NAME})
        add_library(${target_name} MODULE)
        COMMON_TARGET_DEFS()
    else()
        if(NOT ARG_SHARED_ONLY)
            # Static Library Definition
            if (NOT ARG_STATIC_ONLY)
                set(target_suffix "_static")
            endif()
            set(target_name ${PROJECT_NAME}_${ARG_NAME}${target_suffix})
            set(target_alias ${PROJECT_NAME}::${ARG_NAME}${target_suffix})
            add_library(${target_name} STATIC)
            COMMON_TARGET_DEFS()
        endif()
        if(NOT ARG_STATIC_ONLY)
            # Shared Library Definition
            set(target_name ${PROJECT_NAME}_${ARG_NAME})
            set(target_alias ${PROJECT_NAME}::${ARG_NAME})
            add_library(${target_name} SHARED)
            COMMON_TARGET_DEFS()
        endif()
    endif()

    if(NOT NO_INSTALL)
        # Set the component to default if it wasn't specified
        if(NOT ARG_COMPONENT)
            set(ARG_COMPONENT Core)
        endif()
        # Add the component to a list of components in the project
        # if it wasn't already present
        get_property(component_list GLOBAL PROPERTY ${PROJECT_NAME}_COMPONENT_LIST)
        if(NOT ${ARG_COMPONENT} IN_LIST component_list)
            list(APPEND component_list ${ARG_COMPONENT})
        endif()
        set_property(GLOBAL APPEND PROPERTY ${PROJECT_NAME}_COMPONENT_LIST ${component_list})
        # Add the specified dependent packages/components to a list for the
        # specified component
        get_property(dep_list GLOBAL PROPERTY ${PROJECT_NAME}_${ARG_COMPONENT}_DEPENDS_ON)
        foreach(dep IN LISTS ARG_DEPENDS_ON)
            if (NOT ${dep} IN_LIST dep_list)
                list(APPEND dep_list ${dep})
            endif()
        endforeach()
        set_property(GLOBAL APPEND PROPERTY ${PROJECT_NAME}_${ARG_COMPONENT}_DEPENDS_ON ${dep_list})

        # Define install for current targets
        install(TARGETS ${install_targets} EXPORT ${PROJECT_NAME}_${ARG_COMPONENT}
                RUNTIME
                    DESTINATION ${CMAKE_INSTALL_BINDIR}
                LIBRARY
                    DESTINATION ${CMAKE_INSTALL_LIBDIR}
                ARCHIVE
                    DESTINATION ${CMAKE_INSTALL_LIBDIR}
                PUBLIC_HEADER
                    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
        install(DIRECTORY ${ARG_INCLUDE_DIRS}
                    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
                    PATTERN "*.h"
                    PATTERN "*.H"
                    PATTERN "*.hpp"
                    PATTERN "*.hxx"
                    PATTERN "*.hh"
                    PATTERN "*.h++"
                    PATTERN "*.cuh")
    endif()
endfunction()

function(default_install_current_project) # [2]
    # Get list of components for project
    get_property(comps GLOBAL PROPERTY ${PROJECT_NAME}_COMPONENT_LIST)
    # Export config file for each component
    foreach(comp IN LISTS comps)
        get_property(${comp}_DEPENDS_ON GLOBAL PROPERTY ${PROJECT_NAME}_${comp}_DEPENDS_ON)
        if(${comp}_DEPENDS_ON)
            string(APPEND package_dependencies "set(${comp}_DEPENDS_ON ${${comp}_DEPENDS_ON})\n")
        endif()
        install(EXPORT ${PROJECT_NAME}_${comp}
                DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
                NAMESPACE ${PROJECT_NAME}::
                FILE ${PROJECT_NAME}_${comp}.cmake)
    endforeach()
    # Export config file for package
    include(CMakePackageConfigHelpers)
    set(module_dir "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}")
    configure_package_config_file(
            ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/ProjectConfig.cmake.in ${PROJECT_NAME}Config.cmake
            INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
            PATH_VARS module_dir
            NO_SET_AND_CHECK_MACRO
            NO_CHECK_REQUIRED_COMPONENTS_MACRO)
    write_basic_package_version_file(${PROJECT_NAME}ConfigVersion.cmake
            COMPATIBILITY SameMajorVersion)
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake
            ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
            DESTINATION ${module_dir})
endfunction()

# [3.1] Target Registration
function(register_target) # [3.1.1]
    # Takes target names as arguments, adds them to global and per-project lists
    # so they can be optionally listed using list_targets() and list_project_targets()
    foreach(arg ${ARGV})
        list(APPEND targets ${arg})
    endforeach()
    set_property(GLOBAL APPEND PROPERTY ADDLIB_TARGET_LIST ${targets})
    set_property(GLOBAL APPEND PROPERTY ADDLIB_${PROJECT_NAME}_TARGET_LIST ${targets})
    unset(targets)
endfunction()

function(list_targets) # [3.1.2]
    # Prints out a list of all targets created using add_lib or manually registered
    # with register_target()
    get_property(targets GLOBAL PROPERTY ADDLIB_TARGET_LIST)
    if(targets)
        message(NOTICE "Targets defined by build:")
        foreach(target_name IN LISTS targets)
            get_target_property(type ${target_name} TYPE)
            message(NOTICE "[${type}]\t${target_name}")
        endforeach()
    endif()
endfunction()

function(list_project_targets) # [3.1.3]
    # Prints out a list of all targets in the current project created using add_lib
    # or manually registered with register_target()
    get_property(targets GLOBAL PROPERTY ADDLIB_${PROJECT_NAME}_TARGET_LIST)
    if(targets)
        message(NOTICE "Targets belonging to ${PROJECT_NAME}:")
        foreach(target_name IN LISTS targets)
            get_target_property(type ${target_name} TYPE)
            message(NOTICE "\t[${type}] ${target_name}")
        endforeach()
    endif()
endfunction()

# [3.2] Test Registration
function(register_test) # [3.2.1]
    # Takes test names as arguments, adds them to global and per-project lists
    # so they can be optionally listed using list_tests() and list_project_tests()
    foreach(arg ${ARGV})
        list(APPEND targets ${arg})
    endforeach()
    set_property(GLOBAL APPEND PROPERTY ADDLIB_TEST_LIST ${targets})
    set_property(GLOBAL APPEND PROPERTY ADDLIB_${PROJECT_NAME}_TEST_LIST ${targets})
    unset(targets)
endfunction()

function(list_tests) # [3.2.2]
    # Prints out a list of all tests created using add_lib or manually registered
    # with register_test()
    get_property(targets GLOBAL PROPERTY ADDLIB_TEST_LIST)
    if(targets)
        message(NOTICE "Tests defined by build:")
        foreach(target_name IN LISTS targets)
            message(NOTICE "\t${target_name}")
        endforeach()
    endif()
endfunction()

function(list_project_tests) # [3.2.3]
    # Prints out a list of all tests in the current project created using add_lib
    # or manually registered with register_test()
    get_property(targets GLOBAL PROPERTY ADDLIB_${PROJECT_NAME}_TEST_LIST)
    if(targets)
        message(NOTICE "Tests belonging to ${PROJECT_NAME}:")
        foreach(target_name IN LISTS targets)
            message(NOTICE "\t${target_name}")
        endforeach()
    endif()
endfunction()
