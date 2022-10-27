# AddLib.cmake
Modern CMake Simplified.

AddLib is a single CMake module that adds alternate commands for defining libraries and executables.
It combines many of the target_* and related commands into a simpler, compact interface.

## To-Do
- Improve support for MacOS.

## Feautres
- add_lib or add_exe functions that simplify modern target-based workflows
- Can generate shared and static library variants from one declaration
- Automated installation and packaging for simple executable or library projects
- Integrates with popular testing frameworks
- Designed to be incrementally replaced once your project grows past its scope 

## Usage
Examples can be found in the [examples/](examples/) folder.
```
===========================================================
=== Using AddLib.cmake v2.1.0 - Modern CMake Simplified ===
===========================================================
== Usage: Adding a new executable ==
====================================
add_exe(<name>
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
    [GLOB_TESTS <glob_exprs>...]
)
====================================
== Usage: Adding a new library    ==
====================================
add_lib(<name>
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
    [GLOB_TESTS <expr>...]
)
====================================
== Usage: Configure Installation  ==
====================================
version-string := MAJOR[.MINOR[.PATCH]]
dep-string := <package>[@<version-string>][::<component>]
install_project(
    [COMPATIBILITY AnyNewerVersion|SameMajorVersion|SameMinorVersion|ExactVersion]
    [DEPENDS_ON <dep-string>...]
)
specify_dependency 
    [COMPONENT <component>]
    [DEPENDS_ON <dep-string>...]
)
====================================
== Usage: Configure Packaging     ==
====================================
package_project(
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
    ]
)
====================================
== Help: Usage Information        ==
====================================
addlib_usage()
====================================
== Help: Available targets        ==
====================================
list_targets()
====================================
== Help: Available test frameworks==
====================================
list_test_frameworks()
```

## Conventions
### Target Naming
CMake targets created using the add_lib or add_exe commands use the naming scheme

project_target(_static)

The static suffix is only present for the static variant of a library created using the STATIC_AND_SHARED option

An alias is also created so target names will stay consistent whether or not the created package is consumed through add_subdirectory or find_package

project::target(_static)
### Adding new testing frameworks
To add support for a new test framework create a new file AddLibTest(name).cmake and make sure its containing folder is part of CMAKE_MODULE_PATH.
Then implement the function
```cmake
addlib_integrate_tests(
  TARGET <name>
  SOURCES <sources>...
  LINK <targets>...
)
```
This function is supposed to create and register test target(s) for the specified target.
The test targets should link against the TARGET argument, any framework specific targets, and any extra libraries specified by LINK. It should also register the created tests with CTest.
