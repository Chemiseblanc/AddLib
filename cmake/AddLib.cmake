# =====================================================================
# AddLib.cmake - Modern CMake Simplified.
# Version 2.0.0
# Copyright Matthew Gibson 2022.
# Distributed under the Boost Software License, Version 1.0.
# (See accompanying file LICENSE.txt or copy at 
#  https://www.boost.org/LICENSE_1_0.txt)
# =====================================================================
# Table of Contents:
# 1     - Target Creation
# 1.1    - function(add_exe)
# 1.2    - function(add_lib)
# 1.3    - function(addlib_target)
# 1.3.1   - Target naming
# 1.3.2   - Target attributes
# 1.3.3   - Test creation
# 2     - Installation
# 2.1    - function(install_project)
# 2.2    - function()
# 2.3    - function()
# 3     - Packaging
# 3.1    - function(package_project)
# 3.1.1   - Global packaging variables
# 3.1.2   - Packaging generator detection
# 3.1.3   - Defining package variants
# 3.1.4   - DEB specific options
# 3.1.5   - RPM specific options
# 3.1.6   - Component grouping
# 4     - Utility
# 4.1    - function(register_target)
# 4.2    - function(list_targets)
# 4.3    - function(list_test_backends)
# 5     - Help
# 5.1    - function(addlib_usage)
include_guard(GLOBAL)

# [1] Target Creation
function(add_exe target) # [1.1]
    # Creates a new executable target
    addlib_target(target EXECUTABLE ${ARGN})
endfunction()

function(add_lib target) # [1.2]
    # Creates a new library target
    # Handles setting symbol visibility and creating the export header for shared libraries.
    # Also provides an option to create both shared and static variants of a library.
    # By default the generated targets follow the naming convention
    # ${PROJECT_NAME}::${target}(_static)
    include(CMakeParseArguments)
    set(options
        SHARED
        SHARED_AND_STATIC
        STATIC
        HEADER_ONLY
        MODULE
    )
    set(oneValueArgs
        EXPORT_HEADER
        DEFAULT_VISIBILITY
    )
    set(multiValueArgs
    )
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ARG_DEFAULT_VISIBILITY)
        set(ARG_DEFAULT_VISIBILITY hidden)
    endif()

    # If the library type is not specified it will default to building static libraries
    # unless the option BUILD_SHARED_LIBS is enabled.
    # If we are using this default behavious we need to treat it the same as if we were generating
    # shared and static variants in order to have consistent behaviour. Modules are included in this
    # since they are just a type of shared library intended to be dynamically loaded.
    # To capture this behaviour we can't check if SHARED OR SHARED_AND_STATIC OR MODULE since this doesn't
    # capture the default case, so instead we test against the negation of the other library types.
    if(NOT ARG_STATIC OR NOT ARG_HEADER_ONLY)
        list(REMOVE_ITEM ${ARGN} SHARED SHARED_AND_STATIC)
        include(GenerateExportHeader)

        addlib_target(${target} SHARED PREFIX "${PROJECT_NAME}" ${ARGN})
        if(ARG_SHARED_AND_STATIC)
            addlib_target(${target} STATIC PREFIX "${PROJECT_NAME}" SUFFIX "static" ${ARGN})
        endif()

        # If symbols are hidden generate export header and set relevant options
        string(TOLOWER "${ARG_DEFAULT_VISIBILITY}" visibility)
        if(visibility STREQUAL "hidden")
            include(GenerateExportHeader)
            if(NOT ARG_EXPORT_HEADER)
                message(FATAL_ERROR "A file path must be specified with EXPORT_HEADER when symbols are hidden")
            endif()

            set_target_properties(${PROJECT_NAME}_${target}
                PROPERTIES
                    C_VISIBILITY_PRESET hidden
                    CXX_VISIBILITY_PRESET hidden
                    VISIBILITY_INLINES_HIDDEN TRUE
            )
            generate_export_header(${PROJECT_NAME}_${target}
                BASE_NAME ${target}
                EXPORT_FILE_NAME ${ARG_EXPORT_HEADER}
            )
            target_include_directories(${PROJECT_NAME}_${target}
                PUBLIC
                    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
            )

            if(ARG_SHARED_AND_STATIC)
                string(TOUPPER ${target} TARGET_UPPER)
                target_compile_definitions(${PROJECT_NAME}_${target}_static
                    PUBLIC
                        ${TARGET_UPPER}_STATIC_DEFINE
                )
                target_include_directories(${PROJECT_NAME}_${target}_static
                    PUBLIC
                        $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
                )
            endif()
        elseif(visibility STREQUAL "visible")
            set_target_properties(${PROJECT_NAME}_${target}
                PROPERTIES
                    CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS true)
        else()
            message(FATAL_ERROR "Visibility setting must be one of [hidden|visible]")
        endif()
    else()
        # Passthrough all arguments
        addlib_target(${target} ${ARGN})
    endif()
endfunction()

function(addlib_target target) # [1.3] 
    # A shortcut for handling the boilerplate for a modern target-based workflow
    include(CMakeParseArguments)
    set(options
        STATIC            # Static Library
        SHARED            # Shared Library
        HEADER_ONLY       # Header-Only Library
        MODULE            # Dynamicly Loadable Library
        EXECUTABLE        # Executable
        NO_INSTALL        # Don't install files associated with target
    )
    set(oneValueArgs
        PREFIX             # Generated target prefix (Defaults to ${PROJECT_NAME})
        SUFFIX             # Generated target suffix (Defaults empty, "static" when generating both shared and static libraries)
        TEST_FRAMEWORK     #
        COMPONENT          # Component to assign target to when library is consumed through FIND_PACKAGE(<name> COMPONENT ...)
        DEFAULT_VISIBILITY # Default symbol visibility for libraries
        EXPORT_HEADER
    )
    set(multiValueArgs
        SOURCES GLOB_SOURCES
        INCLUDE_DIRS
        LINK TEST_LINK
        COMPILE_FEATURES
        COMPILE_FLAGS
        PRECOMPILE_HEADERS
        PROPERTIES
        TESTS GLOB_TESTS
        TEST_EXTRA_LINK_TARGETS
        DEPENDS_ON
    )
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(UNIX)
        set(STRICT_FLAGS -Wall -Wextra -pedantic)
    elseif(WIN32)
    endif()

    # [1.3.1]

    if(ARG_STATIC)
        set(target_type STATIC)
    elseif(ARG_SHARED)
        set(target_type SHARED)
    elseif(ARG_HEADER_ONLY)
        set(target_type INTERFACE)
    elseif(ARG_MODULE)
        set(target_type MODULE)
    endif()

    if(ARG_PREFIX)
        set(prefix "${ARG_PREFIX}_")
        set(namespace "${ARG_PREFIX}::")
    endif()
    if (ARG_SUFFIX)
        set(suffix "_${ARG_SUFFIX}")
    endif()
    set(target_name ${prefix}${target}${suffix})
    set(target_alias ${namespace}${target}${suffix})
    register_target(${target_alias})

    if(ARG_EXECUTABLE)
        add_executable(${target_name})
        set_target_properties(${target_name}
            PROPERTIES OUTPUT_NAME ${target}
        )
    else()
        if(WIN32) # Using a generator expression for this worked on windows but failed on ubuntu
            set(libname ${target}${suffix})
        else()
            set(libname ${target})
        endif()

        add_library(${target_name} ${target_type})
        add_library(${target_alias} ALIAS ${target_name})
        set_target_properties(${target_name}
            PROPERTIES 
                EXPORT_NAME ${target}${suffix}
                OUTPUT_NAME ${libname}
        )
    endif()

    # [1.3.2]
    set(visibilityNames
        PUBLIC PRIVATE INTERFACE)

    if(ARG_HEADER_ONLY)
        set(PUBLIC_OR_INTERFACE INTERFACE)
        set(PRIVATE_OR_INTERFACE INTERFACE)
    else()
        set(PUBLIC_OR_INTERFACE PUBLIC)
        set(PRIVATE_OR_INTERFACE PRIVATE)
    endif()

    # target_sources
    cmake_parse_arguments(SOURCES "" "" "${visibilityNames}" ${ARG_SOURCES})
    cmake_parse_arguments(GLOB_SOURCES "" "" "${visibilityNames}" ${ARG_GLOB_SOURCES})
    if(GLOB_SOURCES_PUBLIC)
        file(GLOB ${target_name}_PUBLIC_GLOB_SOURCES CONFIGURE_DEPENDS ${GLOB_SOURCES_PUBLIC})
        list(APPEND ${SOURCES_PUBLIC} ${target_name}_PUBLIC_GLOB_SOURCES)
    endif()
    if(GLOB_SOURCES_PRIVATE)
        file(GLOB ${target_name}_PRIVATE_GLOB_SOURCES CONFIGURE_DEPENDS ${GLOB_SOURCES_PRIVATE})
        list(APPEND ${SOURCES_PRIVATE} ${target_name}_PRIVATE_GLOB_SOURCES)
    endif()
    if(GLOB_SOURCES_UNPARSED_ARGUMENTS)
        file(GLOB ${target_name}_UNPARSED_ARGUMENTS_GLOB_SOURCES CONFIGURE_DEPENDS ${GLOB_SOURCES_UNPARSED_ARGUMENTS})
        list(APPEND ${SOURCES_UNPARSED_ARGUMENTS} ${target_name}_UNPARSED_ARGUMENTS_GLOB_SOURCES)
    endif()
    target_sources(${target_name}
        PUBLIC
            ${SOURCES_PUBLIC}
        PRIVATE
            ${SOURCES_PRIVATE}
        PRIVATE
            ${SOURCES_UNPARSED_ARGUMENTS}
    )

    # target_include_directories
    cmake_parse_arguments(INCLUDE_DIRS "" "" "${visibilityNames}" ${ARG_INCLUDE_DIRS})
    target_include_directories(${target_name}
        ${PUBLIC_OR_INTERFACE}
            $<BUILD_INTERFACE:${INCLUDE_DIRS_PUBLIC}>
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
        PRIVATE
            $<BUILD_INTERFACE:${INCLUDE_DIRS_PRIVATE}>
        INTERFACE
            $<BUILD_INTERFACE:${INCLUDE_DIRS_INTERFACE}>
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
        ${PUBLIC_OR_INTERFACE} # Default
            $<BUILD_INTERFACE:${INCLUDE_DIRS_UNPARSED_ARGUMENTS}>
    )
    list(APPEND install_include_dirs 
        ${INCLUDE_DIRS_PUBLIC}
        ${INCLUDE_DIRS_INTERFACE}
        ${INCLUDE_DIRS_UNPARSED_ARGUMENTS}
    )

    # target_link_libraries
    cmake_parse_arguments(LINKS "" "" "${visibilityNames}" ${ARG_LINK})
    target_link_libraries(${target_name}
        ${PUBLIC_OR_INTERFACE}
            ${LINKS_PUBLIC}
        PRIVATE
            ${LINKS_PRIVATE}
        ${PUBLIC_OR_INTERFACE} # Default
            ${LINKS_UNPARSED_ARGUMENTS}
    )

    # target_compile_features
    cmake_parse_arguments(COMPILE_FEATURES "" "" "${visibilityNames}" ${ARG_COMPILE_FEATURES})
    target_compile_features(${target_name}
        PUBLIC
            ${COMPILE_FEATURES_PUBLIC}
        PRIVATE
            ${COMPILE_FEATURES_PRIVATE}
        PRIVATE # Default
            ${COMPILE_FEATURES_UNPARSED_ARGUMENTS}
    )

    # target_compile_options
    cmake_parse_arguments(COMPILE_FLAGS "" "" "${visibilityNames}" ${ARG_COMPILE_FLAGS})
    target_compile_options(${target_name}
        PUBLIC
            ${COMPILE_FEATURES_PUBLIC}
        PRIVATE
            ${COMPILE_FEATUERS_PRIVATE}
    )

    # target_precompile_headers
    cmake_parse_arguments(PRECOMPILED_HEADERS "" "" "${visibilityNames}" ${ARG_PRECOMPILE_HEADERS})
    target_precompile_headers(${target_name}
        PUBLIC
            ${PRECOMPILED_HEADERS_PUBLIC}
        PRIVATE
            ${PRECOMPILED_HEADERS_PRIVATE}
    )

    # set_target_properties
    if(ARG_PROPERTIES)
        set_target_properties(${target_name} PROPERTIES ${ARG_PROPERTIES})
    endif()

    # [1.3.3]
    if(BUILD_TESTING) 
        if(ARG_TESTS)
            if(ARG_TEST_FRAMEWORK)
                include(AddLibTest${ARG_TEST_FRAMEWORK} OPTIONAL RESULT_VARIABLE test_integration_found)
                if(test_integration_found)
                    addlib_integrate_tests(
                        TARGET ${target_name}
                        SOURCES ${ARG_TESTS}
                        LINK ${ARG_TEST_LINK}
                    )
                else()
                    message(FATAL_ERROR "Unsupported test framework ${ARG_TEST_FRAMEWORK}. Make sure the integration module AddLibTest${ARG_TEST_FRAMEWORK}.cmake is present in your module path.")
                endif()
            else()
                foreach(TEST_SRC IN LISTS ARG_TESTS)
                    cmake_path(GET TEST_SRC STEM TEST)
                    set(test_target ${target_name}_${TEST})
                    add_executable(${test_target} ${TEST_SRC})
                    target_link_libraries(${test_target}
                        PRIVATE
                            ${target_name}
                            ${ARG_TEST_LINK}
                    )
                    add_test(NAME ${test_target} COMMAND ${test_target})
                endforeach()
            endif()
        endif()
    endif()

    # [1.3.4]
    if(NOT ARG_NO_INSTALL)
        # Assign the target to a default package component if one isn't specified
        if(NOT ARG_COMPONENT)
            set(ARG_COMPONENT Unspecified)
        endif()

        # Add the target to a list of targets in the component
        get_property(target_list GLOBAL PROPERTY ${PROJECT_NAME}_${ARG_COMPONENT}_TARGETS)
        list(APPEND target_list ${target_name})
        set_property(GLOBAL PROPERTY ${PROJECT_NAME}_${ARG_COMPONENT}_TARGETS ${target_list})

        # Add include directories to component list
        get_property(include_dir_list GLOBAL PROPERTY ${PROJECT_NAME}_${ARG_COMPONENT}_INCLUDE_DIRS)
        list(APPEND include_dir_list ${install_include_dirs})
        list(REMOVE_DUPLICATES include_dir_list)
        set_property(GLOBAL PROPERTY ${PROJECT_NAME}_${ARG_COMPONENT}_INCLUDE_DIRS ${include_dir_list})

        # Add extra headers
        if(ARG_EXPORT_HEADER)
            get_property(extra_header_list GLOBAL PROPERTY ${PROJECT_NAME}_${ARG_COMPONENT}_EXTRA_HEADERS)
            list(APPEND extra_header_list ${CMAKE_CURRENT_BINARY_DIR}/${ARG_EXPORT_HEADER})
            list(REMOVE_DUPLICATES extra_header_list)
            set_property(GLOBAL PROPERTY ${PROJECT_NAME}_${ARG_COMPONENT}_EXTRA_HEADERS ${extra_header_list})
        endif()

        # Add the component to a list of components in the project if it doesn't already exist
        get_property(component_list GLOBAL PROPERTY ${PROJECT_NAME}_COMPONENT_LIST)
        list(APPEND component_list ${ARG_COMPONENT})
        list(REMOVE_DUPLICATES component_list)
        set_property(GLOBAL PROPERTY ${PROJECT_NAME}_COMPONENT_LIST ${component_list})

        # Add specified dependencies to the component dependency list if they aren't already present
        get_property(dep_list GLOBAL PROPERTY ${PROJECT_NAME}_${ARG_COMPONENT}_DEPENDS_ON)
        list(APPEND dep_list ${ARG_DEPENDS_ON})
        list(REMOVE_DUPLICATES dep_list)
        set_property(GLOBAL PROPERTY ${PROJECT_NAME}_${ARG_COMPONENT}_DEPENDS_ON ${dep_list})

        # Add the target type to a component list
        get_property(target_types GLOBAL PROPERTY ${PROJECT_NAME}_${ARG_COMPONENT}_TARGET_TYPES)
        if(ARG_EXECUTABLE)
            list(APPEND target_types EXECUTABLE)
        else()
            list(APPEND target_types ${target_type})
        endif()
        list(REMOVE_DUPLICATES target_types)
        set_property(GLOBAL PROPERTY ${PROJECT_NAME}_${ARG_COMPONENT}_TARGET_TYPES ${target_types})
    endif()
endfunction()

# [2]
function(install_project) # [2.1]
    include(GNUInstallDirs)
    include(InstallRequiredSystemLibraries)
    include(CMakeParseArguments)

    set(options)
    set(oneValueArgs "COMPATIBILITY")
    set(multiValueArgs "DEPENDS_ON")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${DEPENDS_ON}" ${ARGN})
    if(ARG_COMPATIBILITY)
        specify_version_compatability(${ARG_COMPATIBILITY})
    endif()
    if(ARG_DEPENDS_ON)
        specify_dependency(DEPENDS_ON ${ARG_DEPENDS_ON})
    endif()
    

    set(CMAKE_INSTALL_DEFAULT_COMPONENT_NAME ${PROJECT_NAME}_Unspecified)
    get_property(components GLOBAL PROPERTY ${PROJECT_NAME}_COMPONENT_LIST)

    # Install targets for each component
    foreach(component IN LISTS components)
        get_property(targets GLOBAL PROPERTY ${PROJECT_NAME}_${component}_TARGETS)
        get_property(dependencies GLOBAL PROPERTY ${PROJECT_NAME}_${component}_DEPENDS_ON)
        if(dependencies)
            string(APPEND package_dependencies "set(${component}_DEPENDS_ON ${${component}_DEPENDS_ON})\n")
        endif()
        install(
            TARGETS ${targets} 
            EXPORT ${PROJECT_NAME}_${component}
            RUNTIME
                DESTINATION ${CMAKE_INSTALL_BINDIR}
                COMPONENT ${PROJECT_NAME}_${component}
            LIBRARY
                DESTINATION ${CMAKE_INSTALL_LIBDIR}
                COMPONENT ${PROJECT_NAME}_${component}
            ARCHIVE
                DESTINATION ${CMAKE_INSTALL_LIBDIR}
                COMPONENT ${PROJECT_NAME}_${component}_static

        )
        get_property(include_dirs GLOBAL PROPERTY ${PROJECT_NAME}_${component}_INCLUDE_DIRS)
        install(
            DIRECTORY ${include_dirs}
            COMPONENT ${PROJECT_NAME}_${component}_dev
            DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
            PATTERN "*"
        )
        
        get_property(extra_headers GLOBAL PROPERTY ${PROJECT_NAME}_${component}_EXTRA_HEADERS)
        install(
            FILES ${extra_headers}
            COMPONENT ${PROJECT_NAME}_${component}_dev
            DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
        )
        install(
            EXPORT ${PROJECT_NAME}_${component}
            DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
            NAMESPACE ${PROJECT_NAME}::
            FILE ${PROJECT_NAME}_${component}.cmake
            COMPONENT ${PROJECT_NAME}_${component_name}_dev
        )
    endforeach()

    # Create and install the project config and version files.
    include(CMakePackageConfigHelpers)
    set(module_dir "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}")
    configure_package_config_file(
        ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/ProjectConfig.cmake.in ${PROJECT_NAME}Config.cmake
        INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
        PATH_VARS module_dir
        NO_SET_AND_CHECK_MACRO
        NO_CHECK_REQUIRED_COMPONENTS_MACRO
    )
    get_property(policy GLOBAL PROPERTY ${PROJECT_NAME}_COMPATIBILITY)
    if(NOT policy)
        set(policy ExactVersion)
    endif()
    write_basic_package_version_file(${PROJECT_NAME}ConfigVersion.cmake 
        COMPATIBILITY ${policy}
    )
    install(
        FILES 
            ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake
            ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
        DESTINATION ${module_dir}    
    )
endfunction()

function(specify_dependency) # [2.2]
    # Allows you to specify dependencies on a per-component basis instead of
    # through the DEPENDS_ON option for add_lib
    set(noValues)
    set(singleValues
            COMPONENT)
    set(multiValues
            DEPENDS_ON)
    cmake_parse_arguments(ARG "${noValues}" "${singleValues}" "${multiValues}" ${ARGN})

    if(NOT ARG_COMPONENT)
        set(ARG_COMPONENT Core)
    endif()

    get_property(dep_list GLOBAL PROPERTY ${PROJECT_NAME}_${ARG_COMPONENT}_DEPENDS_ON)
    list(APPEND dep_list ${dep})
    list(REMOVE_DUPLICATES dep_list)
    set_property(GLOBAL PROPERTY ${PROJECT_NAME}_${ARG_COMPONENT}_DEPENDS_ON ${dep_list})
endfunction()

function(specify_version_compatability policy) # [2.3]
    # Set the version compatability policy for generated packages
    # This is used if find_package is given a version parameter.
    set(allowed_options "AnyNewerVersion;SameMajorVersion;SameMinorVersion;ExactVersion")
    if(${policy} IN_LIST allowed_options)
        set_property(GLOBAL PROPERTY ${PROJECT}_COMPATIBILITY ${policy})
    else()
        message(FATAL_ERROR "Unknown compatability policy ${policy}. Must be one of: ${allowed_options}")
    endif()
endfunction()

# [3]
function(package_project) # [3.1]
    set(flags)
    set(values
        VENDOR
        SUMMARY
        DESCRIPTION_FILE
        WELCOME_FILE
        LICENSE_FILE
        README_FILE
        CONTACT
    )
    set(lists
        SIGN_PACKAGE
    )
    cmake_parse_arguments(ARG "${flags}" "${values}" "${lists}" ${ARGN})
    # if(NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    #     message(FATAL_ERROR "package_project must be called from your root CMakeLists.txt")
    # endif()
    
    # [3.1.1] - Global packaging variables
    set(CPACK_PACKAGE_NAME ${PROJECT_NAME})
    set(CPACK_PACKAGE_VENDOR ${ARG_VENDOR})
    set(CPACK_PACKAGE_INSTALL_DIRECTORY ${CPACK_PACKAGE_NAME})
    set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
    set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
    set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY ${ARG_SUMMARY})
    set(CPACK_PACKAGE_DESCRIPTION_FILE ${ARG_DESCRIPTION_FILE})
    set(CPACK_RESOURCE_FILE_WELCOME ${ARG_WELCOME_FILE})
    set(CPACK_RESOURCE_FILE_LICENSE ${ARG_LICENSE_FILE})
    set(CPACK_RESOURCE_FILE_README ${ARG_README_FILE})
    set(CPACK_COMPONENTS_GROUPING ONE_PER_GROUP)
    set(CPACK_PACKAGE_CONTACT ${ARG_CONTACT})

    set(CPACK_VERBATIM_VARIABLES TRUE)
    set(CPACK_SOURCE_IGNORE_FILES
        /\\.git/
        \\.swp
        \\.orig
    )

    if(ARG_SIGN_PACKAGE OR SIGN_PACKAGE IN_LIST ARG_KEYWORDS_MISSING_VALUES)
        if(WIN32)
            windows_sign_exe(${ARG_SIGN_PACKAGE})
        else()
            message(WARNING "Code signing is not supported for this platform.")
        endif()
    endif()

    # [3.1.2] - Enable packaging generators for "package" target
    # [3.1.2.1] - ZIP/TGZ
    if(WIN32)
        list(APPEND available_generators ZIP)
        set(CPACK_SOURCE_GENERATOR ZIP)
    else()
        list(APPEND available_generators TGZ)
        set(CPACK_SOURCE_GENERATOR TGZ)
    endif()
    # [3.1.2.2] - WIX
    find_program(WIX_FOUND candle)
    if(WIX_FOUND)
        list(APPEND available_generators WIX)
    endif()
    # [3.1.2.3] - NSIS
    find_program(NSIS_FOUND makensis)
    if(NSIS_FOUND)
        list(APPEND available_generators NSIS64)
    endif()
    # [3.1.2.4] - NUGET
    find_program(NUGET_FOUND nuget)
    if(NUGET_FOUND)
        list(APPEND available_generators NuGet)
    endif()
    # [3.1.2.5] - IFW
    find_program(IFW_FOUND binarycreator)
    if(IFW_FOUND)
        list(APPEND available_generators IFW)
    endif()
    # [3.1.2.6] - DEB
    find_program(DEB_FOUND dpkg-deb)
    if(DEB_FOUND)
        list(APPEND available_generators DEB)
    endif()
    # [3.1.2.7] - RPM
    find_program(RPM_FOUND rpmbuild)
    if(RPM_FOUND)
        list(APPEND available_generators RPM)
    endif()

    set(CPACK_GENERATOR ${available_generators} CACHE STRING "Enabled packaging generators")
    # [3.1.3] - Creating packaging variants

    # Figure out the different types of targets present in the project
    # and use that to determine which types of packages to create
    get_property(components GLOBAL PROPERTY ${PROJECT_NAME}_COMPONENT_LIST)
    foreach(component IN LISTS components)
        get_property(target_types GLOBAL PROPERTY ${PROJECT_NAME}_${component}_TARGET_TYPES)
        list(APPEND project_contains ${target_types})
    endforeach()
    list(REMOVE_DUPLICATES project_contains)

    # There are four packaging configurations a project can take.
    # - Dynamically linked executable
    # - Statically linked executable
    # - Shared Library
    # - Static / Header-Only Library
    # The different package options form a hierachy and are merged into
    # the parent package if the parent would otherwise be empty.
    # - Base: Executables, shared libraries, and dynamically loadable libraries
    #  - Development: Header files
    #   - Static: Static Libraries
    set(base_group ${PROJECT_NAME})
    if(EXECUTABLE IN_LIST project_contains)
        set(dev_group ${PROJECT_NAME}_dev)
        if(SHARED IN_LIST project_contains)
            set(static_group ${PROJECT_NAME}_static)
        else()
            set(static_group ${PROJECT_NAME}_dev)
        endif()
    else()
        if (SHARED IN_LIST project_contains)
            set(dev_group ${PROJECT_NAME}_dev)
            set(static_group ${PROJECT_NAME}_static)
        else()
            set(dev_group ${PROJECT_NAME})
            set(static_group ${PROJECT_NAME})
        endif()
    endif()

    # [3.1.4] DEB specific options
    set(CPACK_DEB_COMPONENT_INSTALL ON)
    set(CPACK_DEBIAN_ENABLE_COMPONENT_DEPENDS ON)
    set(CPACK_DEBIAN_PACKAGE_DEPENDS)
    foreach(component IN LISTS components)
        string(TOUPPER ${base_group} comp)
        string(TOLOWER ${PROJECT_NAME} package)
        set(CPACK_DEBIAN_${comp}_PACKAGE_NAME ${package})
        set(CPACK_DEBIAN_${comp}_FILE_NAME DEB-DEFAULT) 
        set(CPACK_DEBIAN_${comp}_PACKAGE_SHLIBDEPS ON)
        if(NOT ${dev_group} STREQUAL ${base_group})
            string(TOUPPER ${dev_group} comp)
            set(CPACK_DEBIAN_${comp}_PACKAGE_NAME ${package}-dev)
            set(CPACK_DEBIAN_${comp}_FILE_NAME DEB-DEFAULT)
            set(CPACK_DEBIAN_${comp}_PACKAGE_SHLIBDEPS ON)
            set(CPACK_COMPONENT_${comp}_DEPENDS ${base_group})
        endif()
        if(NOT ${static_group} STREQUAL ${dev_group})
            string(TOUPPER ${static_group} comp)
            set(CPACK_DEBIAN_${comp}_PACKAGE_NAME ${package}-static)
            set(CPACK_DEBIAN_${comp}_FILE_NAME DEB-DEFAULT)
            set(CPACK_DEBIAN_${comp}_PACKAGE_SHLIBDEPS ON)
            set(CPACK_COMPONENT_${comp}_DEPENDS ${dev_group})
        endif()
    endforeach()

    # [3.1.5] RPM specific options
    set(CPACK_RPM_COMPONENT_INSTALL ON)
    foreach(component IN LISTS components)
        string(TOUPPER ${base_group} comp)
        string(TOLOWER ${PROJECT_NAME} package)
        set(CPACK_RPM_${comp}_PACKAGE_NAME ${package})
        set(CPACK_RPM_${comp}_FILE_NAME RPM-DEFAULT) 
        set(CPACK_RPM_${comp}_PACKAGE_AUTOREQPROV ON)
        if(NOT ${dev_group} STREQUAL ${base_group})
            string(TOUPPER ${dev_group} comp)
            set(CPACK_RPM_${comp}_PACKAGE_NAME ${package}-dev)
            set(CPACK_RPM_${comp}_FILE_NAME RPM-DEFAULT)
            set(CPACK_RPM_${comp}_PACKAGE_AUTOREQPROV ON)
            set(CPACK_COMPONENT_${comp}_DEPENDS ${base_group})
        endif()
        if(NOT ${static_group} STREQUAL ${dev_group})
            string(TOUPPER ${static_group} comp)
            set(CPACK_RPM_${comp}_PACKAGE_NAME ${package}-static)
            set(CPACK_RPM_${comp}_FILE_NAME RPM-DEFAULT)
            set(CPACK_RPM_${comp}_PACKAGE_AUTOREQPROV ON)
            set(CPACK_COMPONENT_${comp}_DEPENDS ${dev_group})
        endif()
    endforeach()

    # Make sure all CPACK_* variables are set before including
    include(CPack)

    # [3.1.6] Component group creation and assignment
    # Define the project-wide installation groups
    cpack_add_component_group(${base_group}
        DISPLAY_NAME "Base Install"
    )
    if(NOT ${dev_group} STREQUAL ${base_group})
        cpack_add_component_group(${dev_group}
            DISPLAY_NAME "Development Prerequisites"
            PARENT_GROUP ${base_group}
        )
    endif()
    if (NOT ${static_group} STREQUAL ${dev_group})
        cpack_add_component_group(${static_group}
            DISPLAY_NAME "Static Libraries"
            PARENT_GROUP ${dev_group}
        )
    endif()

    # Assign the install groups for each component to the
    # corresponding project-wide group.
    foreach(component IN LISTS components)
            cpack_add_component(${PROJECT_NAME}_${component}
                REQUIRED
                GROUP ${base_group}
            )
            cpack_add_component(${PROJECT_NAME}_${component}_dev
                GROUP ${dev_group}
            )
            cpack_add_component(${PROJECT_NAME}_${component}_static
                GROUP ${static_group}
            )
    endforeach()
endfunction()

# [4]
function(register_target tgt) # [4.1]
    set_property(GLOBAL APPEND PROPERTY ${PROJECT_NAME}_TARGETS ${tgt})
endfunction()

function(list_targets) # [4.2]
    get_property(project_targets GLOBAL PROPERTY ${PROJECT_NAME}_TARGETS)
    message(NOTICE "Targets in project ${PROJECT_NAME}:")
    foreach(target IN LISTS project_targets)
        get_target_property(type ${target} TYPE)
        message(NOTICE "\t[${type}] ${target}")
    endforeach()
endfunction()

function(list_test_frameworks) # [4.3]
    foreach(dir IN LISTS CMAKE_MODULE_PATH)
        file(GLOB modules LIST_DIRECTORIES false RELATIVE ${dir} "${dir}/AddLibTest*.cmake")
        list(APPEND found_frameworks ${modules})
    endforeach()
    message(NOTICE "Discovered testing frameworks:")
    foreach(backend IN LISTS found_frameworks)
        string(REGEX MATCH "AddLibTest(.+)\.cmake" backend_name ${backend})
        message(NOTICE "\t${CMAKE_MATCH_1}")
    endforeach()
endfunction()

function(windows_sign_exe) # [4.4]
    include(CMakeParseArguments)
    set(options
    )
    set(oneValueArgs
        CERT_FILE
        ALGORITHM
    )
    set(multiValueArgs
    )
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(ARG_CERT_FILE)
        list(APPEND SIGNTOOL_ARGS "/ac" "${ARG_CERT_FILE}")
    else()
        list(APEND SIGNTOOL_ARGS "/a")
    endif()
    if(ARG_ALGORITHM)
        list(APPEND SIGNTOOL_ARGS "/fd" "${ARG_ALGORITHM}")
    else()
        list(APPEND SIGNTOOL_ARGS "/fd" "certHash")
    endif()

    find_program(SIGNTOOL_EXE signtool)
    if(NOT SIGNTOOL_EXE)
        message(FATAL_ERROR "Unable to locate signtool.exe")
    endif()
    set(SIGNTOOL_ARGS)

    set(scriptFile ${PROJECT_BINARY_DIR}/AddLibSignWinExe.cmake)
    configure_file(
        ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/AddLibSignWinExe.cmake.in 
        ${scriptFile}
        @ONLY
    )

    set(CPACK_PRE_BUILD_SCRIPTS ${scriptFile} PARENT_SCOPE)
    set(CPACK_POST_BUILD_SCRIPTS ${scriptFile} PARENT_SCOPE)
endfunction()

# [5]
function(addlib_usage) # [5.1]
    message(NOTICE "===========================================================")
    message(NOTICE "=== Using AddLib.cmake v2.0.0 - Modern CMake Simplified ===")
    message(NOTICE "===========================================================")
    #message(NOTICE "====================================")
    message(NOTICE "== Usage: Adding a new executable ==")
    message(NOTICE "====================================")
    message(NOTICE "add_exe(<name>
    [SOURCES <sources>... [PUBLIC <sources>...] [PRIVATE <sources>...] [INTERFACE <sources>...]]
    [GLOB_SOURCES] <expr>... [PUBLIC <expr>... ] [PRIVATE <expr>... ] [INTERFACE <expr>...]]
    [INCLUDE_DIRS <dirs>... [PUBLIC <dirs>... ] [PRIVATE <dirs>... ] [INTERFACE <dirs>...]]
    [COMPILE_FEATURES <features>... [PUBLIC <features>...] [PRIVATE <features>...] [INTERFACE <features>...]]
    [COMPILE_FLAGS <flags>... [PUBLIC <flags>... ] [PRIVATE <flags>... ] [INTERFACE <flags>...]]
    [PRECOMPILE_HEADERS <headers>... [PUBLIC <headers>...] [PRIVATE <headers>...] [INTERFACE <headers>...]]
    [PROPERTIES <properties>...]

    [NO_INSTALL]
    [COMPONENT <component>]
    [DEPENDS_ON <components>...]
    
    [TEST_FRAMEWORK <framework>] 
    [TESTS <test_sources>...]
    [GLOB_TESTS <glob_exprs>...]\n)")
    message(NOTICE "====================================")
    message(NOTICE "== Usage: Adding a new library    ==")
    message(NOTICE "====================================")
    message(NOTICE "add_lib(<name>
    [SHARED|SHARED_AND_STATIC|STATIC|HEADER_ONLY|MODULE]

    [DEFAULT_VISIBILITY hidden|visible]
    [EXPORT_HEADER <path>]

    [SOURCES <sources>... [PUBLIC <sources>...] [PRIVATE <sources>...] [INTERFACE <sources>...]]
    [GLOB_SOURCES] <expr>... [PUBLIC <expr>... ] [PRIVATE <expr>... ] [INTERFACE <expr>...]]
    [INCLUDE_DIRS <dirs>... [PUBLIC <dirs>... ] [PRIVATE <dirs>... ] [INTERFACE <dirs>...]]
    [COMPILE_FEATURES <features>... [PUBLIC <features>...] [PRIVATE <features>...] [INTERFACE <features>...]]
    [COMPILE_FLAGS <flags>... [PUBLIC <flags>... ] [PRIVATE <flags>... ] [INTERFACE <flags>...]]
    [PRECOMPILE_HEADERS <headers>... [PUBLIC <headers>...] [PRIVATE <headers>...] [INTERFACE <headers>...]]
    [PROPERTIES <properties>...]

    [NO_INSTALL]
    [COMPONENT <component>]
    [DEPENDS_ON <components>...]
    
    [TEST_FRAMEWORK <framework>] 
    [TESTS <test_sources>...]
    [GLOB_TESTS <expr>...]\n)")
    message(NOTICE "====================================")
    message(NOTICE "== Usage: Configure Installation  ==")
    message(NOTICE "====================================")
    message(NOTICE "version-string := MAJOR[.MINOR[.PATCH]]")
    message(NOTICE "dep-string := <Package>[@<version-string>][::<component>]")
    message(NOTICE "install_project(
    [COMPATIBILITY AnyNewerVersion|SameMajorVersion|SameMinorVersion|ExactVersion]
    [DEPENDS_ON <dep-string>...]\n)")
    message(NOTICE "specify_dependency 
    [COMPONENT <component>]
    [DEPENDS_ON <dep-string>...]\n)")
    message(NOTICE "====================================")
    message(NOTICE "== Usage: Configure Packaging     ==")
    message(NOTICE "====================================")
    message(NOTICE "package_project(
    CONTACT <contact>
    [VENDOR <organization>]
    [SUMMARY <short description>]
    [WELCOME_FILE <path>]
    [DESCRIPTION_FILE <path>]
    [README_FILE <path>]
    [LICENSE_FILE <path>]
    [SIGN_PACKAGE
        [CERT_FILE <certificate>]
        [ALGORITHM <algorithm>]
    ]\n)")
    message(NOTICE "====================================")
    message(NOTICE "== Help: Usage Information        ==")
    message(NOTICE "====================================")
    message(NOTICE "addlib_usage()")
    message(NOTICE "====================================")
    message(NOTICE "== Help: Available targets        ==")
    message(NOTICE "====================================")
    message(NOTICE "list_targets()")
    message(NOTICE "====================================")
    message(NOTICE "== Help: Available test frameworks==")
    message(NOTICE "====================================")
    message(NOTICE "list_test_frameworks()")
endfunction()