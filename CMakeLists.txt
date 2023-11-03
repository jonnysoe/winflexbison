cmake_minimum_required(VERSION 3.0.0 FATAL_ERROR)

option(USE_STATIC_RUNTIME "Use static runtime for OS shipped without VC Runtime" OFF)

# CMake features that configures other CMake variables need to be set before project

# Policy needs to be set before certain CMake features are used
cmake_policy(SET CMP0091 NEW)   # CMAKE_MSVC_RUNTIME_LIBRARY

# Use static runtime library so that it will also work on PC without Visual C++ Redistributable
# https://learn.microsoft.com/en-us/cpp/c-runtime-library/crt-library-features?view=msvc-170
# Equivalent to adding:
# - Release: /MT (-D_MT --dependent-lib=libcmt)
# - Debug: /MDd (-D_DLL -D_MT --dependent-lib=msvcrtd)
if(USE_STATIC_RUNTIME)
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:DebugDLL>")
endif()

project (winflexbison)

if(NOT MSVC AND NOT CMAKE_C_SIMULATE_ID MATCHES MSVC AND NOT CMAKE_CXX_SIMULATE_ID MATCHES MSVC)
    # Only compatible with VC Runtime
    message(FATAL_ERROR "Only VC Runtime Build is supported (current compiler: \"${CMAKE_CXX_COMPILER_ID}\")")
endif()

add_definitions(-D_CRT_SECURE_NO_WARNINGS)

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  add_definitions(-D_DEBUG)
endif()

# next line needed for compile in C (nor CPP) mode (ucrt headers bug)
add_definitions(-Dinline=__inline)
# next line needed for VS2017 only
add_definitions(-Drestrict=__restrict)

set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /W3 /Od /Zi /EHsc")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /W3 /GL /Od /Oi /Gy /Zi /EHsc")

# Define Release by default.
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release")
  message(STATUS "Build type not specified: Use Release by default.")
endif()

# Inform user if they've specifically building with static version of CRT.
if(USE_STATIC_RUNTIME)
    message(STATUS "Using /MT for STATIC C runtime")
endif()

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    # Output Variables
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG "${CMAKE_CURRENT_LIST_DIR}/bin/Debug")
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_CURRENT_LIST_DIR}/bin/Release")

    if (MSVC)
        # MSVC and Clang-cl
        add_compile_definitions("__extension__")
        add_compile_options("/source-charset:utf-8")
        # Suppress compiler warnings for GNU coding style.
        add_compile_options(
            /wd4018     # comparator on mismatching signed/unsigned variables
            /wd4090     # const-pointer, pointer-to-const, const-pointer-to-const are not always compatible.
            /wd4116     # DEFAULT_ALIGNMENT uses __alignof__ on an anonymous struct in MSVC
            /wd4146     # minus operator on unsigned type
            /wd4307     # intentional overflow in intprops.h
            /wd4308     # assigment of signedvalue to unsigned typo
            # Optional - disabled for now but potential invalid underlying conversions worth checking out
            /wd4244     # narrowing conversion truncation, possible loss of data
            /wd4267     # initialized with narrowing conversion, truncation, possible loss of data
            # /wd4477     # see -Wno-format below
        )
    elseif(CMAKE_C_COMPILER_FRONTEND_VARIANT MATCHES GNU OR CMAKE_CXX_COMPILER_FRONTEND_VARIANT MATCHES GNU)
        # Clang
        # https://gitlab.kitware.com/cmake/cmake/-/issues/23530
        # Clang does not require additional parameters for UTF-8 source files, but should KIV the above flag.

        # Suppress compiler warnings for GNU coding style.
        add_compile_options(
            -Wno-pointer-sign               # pointers are not signed, but code base mixes signed/unsigned pointers.
            -Wno-incompatible-pointer-types # const-pointer, pointer-to-const, const-pointer-to-const are not always compatible.
            # https://devblogs.microsoft.com/oldnewthing/20050131-00/?p=36563
            # Left the string format warning intact as a reminder, because long is different on Windows x64:
            # - ld is long which is 32-bit.
            # - lld is long long which is 64-bit.
            # -Wno-format
        )
    endif ()
endif ()



add_subdirectory(common)
add_subdirectory(flex)
add_subdirectory(bison)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    # CPACK
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
      install(DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG}/" DESTINATION "./")
    else()
      install(DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE}/" DESTINATION "./")
    endif()

    install(DIRECTORY "custom_build_rules/" DESTINATION "./custom_build_rules/")
    install(DIRECTORY "bison/data/" DESTINATION "./data/")
    install(FILES "flex/src/FlexLexer.h" DESTINATION "./")
    install(FILES "changelog.md" DESTINATION "./")
    install(FILES "COPYING" DESTINATION "./")
    install(FILES "COPYING.DOC" DESTINATION "./")
    install(FILES "README.md" DESTINATION "./")

    set(PACKAGE_GENERATORS_DEFAULT ZIP)

    set(CPACK_GENERATOR ${PACKAGE_GENERATORS_DEFAULT} CACHE STRING "List of CPack Generators which will be created by the 'PACKAGE' target. Default: ZIP")
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Winflexbison - Flex and Bison for Windows")

    set(PROJECT_VERSION "$ENV{WINFLEXBISON_VERSION}")
    if(NOT PROJECT_VERSION)
        set(PROJECT_VERSION "master")
        find_package(Git QUIET)
        if(GIT_FOUND)
            # Get tag name
            execute_process(COMMAND ${GIT_EXECUTABLE} describe --tags --abbrev=0
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                OUTPUT_VARIABLE GIT_TAG_NAME
                OUTPUT_STRIP_TRAILING_WHITESPACE
                ERROR_QUIET)

            # Get branch name
            execute_process(COMMAND ${GIT_EXECUTABLE} branch --show-current
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                OUTPUT_VARIABLE GIT_BRANCH_NAME
                OUTPUT_STRIP_TRAILING_WHITESPACE
                ERROR_QUIET)

            set(PROJECT_VERSION ${GIT_TAG_NAME})

            # Tags do not have branch name, so this is a valid branch
            if(NOT ${GIT_BRANCH_NAME} STREQUAL "")

                set(PROJECT_VERSION ${GIT_BRANCH_NAME})

                # If branch is master, need to check if is ahead of latest tag
                if(${GIT_BRANCH_NAME} STREQUAL "master" OR ${GIT_BRANCH_NAME} STREQUAL "main")
                    # Get tag hash
                    execute_process(COMMAND ${GIT_EXECUTABLE} rev-list -n 1 ${GIT_TAG_NAME}
                        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                        OUTPUT_VARIABLE GIT_TAG_HASH
                        OUTPUT_STRIP_TRAILING_WHITESPACE
                        ERROR_QUIET)

                    # Get tag hash
                    execute_process(COMMAND ${GIT_EXECUTABLE} rev-parse HEAD
                        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                        OUTPUT_VARIABLE GIT_BRANCH_HASH
                        OUTPUT_STRIP_TRAILING_WHITESPACE
                        ERROR_QUIET)

                    # The latest tag is also master, so revert to tag name
                    if("${GIT_TAG_HASH}" STREQUAL "${GIT_BRANCH_HASH}")
                        set(PROJECT_VERSION ${GIT_TAG_NAME})
                    endif()
                endif()
            endif()
        endif()
    endif()
    set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}" CACHE STRING "Complete version of the created package.")

    set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY OFF)
    set(CPACK_ARCHIVE_COMPONENT_INSTALL OFF)
    set(CPACK_MONOLITHIC_INSTALL ON)

    set(CPACK_PACKAGE_FILE_NAME "win_flex_bison-${CPACK_PACKAGE_VERSION}")

    include(CPack)
endif()
