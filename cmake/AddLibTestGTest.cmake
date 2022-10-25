include_guard(GLOBAL)

function(addlib_integrate_tests)
    include(CMakeParseArguments)
    set(options)
    set(oneValueArgs
        TARGET
    )
    set(multiValueArgs
        SOURCES
        LINK
    )
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    find_package(GTest REQUIRED)
    add_executable(${target}_test
        ${test_sources}
    )
    target_link_libraries(${target}_test
        PRIVATE
            ${target}
            ${test_link}
            GTest::gtest
            GTest::gtest_main
    )
    gtest_discover_tests(
        ${target}_test
    )
endfunction()