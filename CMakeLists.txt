cmake_minimum_required(VERSION 3.20)

if(DEFINED PROJECT_NAME)
    set(IS_SUBPROJECT true)
endif()

project(AddLib
        VERSION 2.1.0
        DESCRIPTION "Simplified interfaces for modern target-based workflows"
        HOMEPAGE_URL "https://github.com/Chemiseblanc/AddLib"
        )

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
if(IS_SUBPROJECT)
    set(CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH}" PARENT_SCOPE)
endif()

if(NOT IS_SUBPROJECT)
    option(BUILD_EXAMPLES "Build Example Projects" OFF)
    if(BUILD_EXAMPLES)
        include(CTest) # Needed to pick up tests defined by examples
        add_subdirectory(examples)
    else()
        include(GNUInstallDirs)
        include(CMakePackageConfigHelpers)
        write_basic_package_version_file(
            AddLibConfigVersion.cmake
            COMPATIBILITY SameMajorVersion
            ARCH_INDEPENDENT
        )
        install(
            DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/cmake/
            DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/cmake/AddLib
        )
        install(
            FILES ${CMAKE_CURRENT_BINARY_DIR}/AddLibConfigVersion.cmake
            DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/cmake/AddLib
        )

        if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
            set(CPACK_PACKAGE_VENDOR "AddLib")
            set(CPACK_PACKAGE_CONTACT "Matt Gibson <matt@mgibson.ca>")
            set(CPACK_SOURCE_IGNORE_FILES
                /\\.git/
                \\.gitattributes
                \\.gitignore
                /\\.github/
                /out/
            )
            set(CPACK_VERBATIM_VARIABLES TRUE)
            
            set(CPACK_RPM_PACKAGE_LICENSE "Boost Software License - Version 1.0")
            set(CPACK_RPM_PACKAGE_ARCHITECTURE "noarch")
            
            include(CPack)
        endif()
    endif() # BUILD_EXAMPLES
endif() # IS_SUBPROJECT