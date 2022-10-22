# AddLib.cmake
Modern CMake Simplified.

AddLib is a single CMake module that adds alternate commands for defining libraries and executables.
It combines many of the target_* and related commands into a simpler, compact interface.

## To-Do
- Make symbol visibility handling more consistent
- Testing framework integration
- Packaging this library

## Feautres
- add_lib or add_exe functions that simplify modern target-based workflows
- Can generate shared and static library variants from one declaration
- Automated installation and packaging for simple executable or library projects
- Integrates with popular testing frameworks
- Designed to be incrementally replaced once your project grows past its scope 

## Usage
Examples can be found in the [examples/](examples/) folder.
### Defining Libraries
```cmake
add_lib(ourlib
  SHARED_AND_STATIC
  SOURCES
    ...
  INCLUDE_DIRS
    ...
  LINK
    PUBLIC
      ...
    PRIVATE
      ...
)
```
### Defining Executables
```cmake
add_exe(ourexe
  SOURCES
    ...
  LINK
    ...
)
```
### Unit Testing
Without a framework:
```cmake
add_lib(ourlib
  ...
  TESTS
    tests/foo.cpp
  )
```

With a framework:
```cmake
add_lib(ourlib
  ...
  TEST_FRAMEWORK GTest
  TESTS
    tests/foo.cpp
)
```
### Installation
```cmake
  add_lib(...)
  add_exe(...)
  install_project()
```
### Packaging
```cmake
  add_lib(...)
  add_exe(...)
  install_project()
  package_project(
    CONTACT "John Doe <foo@example.com>"
  )
```

## Conventions
### Target Naming
CMake targets created using the add_lib or add_exe commands use the naming scheme

project_target(_static)

The static suffix is only present for the static variant of a library created using the STATIC_AND_SHARED option

An alias is also created so target names will stay consistent whether or not the created package is consumed through add_subdirectory or find_package

project::target(_static)
