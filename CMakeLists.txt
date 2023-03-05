cmake_minimum_required(VERSION 3.0.0 FATAL_ERROR)

project (winflexbison)

if (NOT CMAKE_CXX_COMPILER_ID MATCHES MSVC)
    # Even MSVC-based Clang is not compatible
    message( WARNING "Visual Studio Build supported only (current compiler: \"${CMAKE_CXX_COMPILER_ID}\")" )
endif()

add_definitions(-D_CRT_SECURE_NO_WARNINGS)

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  add_definitions(-D_DEBUG)
endif()

# next line needed for compile in C (nor CPP) mode (ucrt headers bug)
add_definitions(-Dinline=__inline)
# next line needed for VS2017 only
add_definitions(-Drestrict=__restrict)

set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /W3 /MD /Od /Zi /EHsc")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /W3 /GL /Od /Oi /Gy /Zi /EHsc")

# Define Release by default.
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release")
  message(STATUS "Build type not specified: Use Release by default.")
endif()

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    # Output Variables
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG "${CMAKE_CURRENT_LIST_DIR}/bin/Debug")
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_CURRENT_LIST_DIR}/bin/Release")

    #------------------------------------------------------------------------
    # Static Windows Runtime
    #   Option to statically link to the Windows runtime. Maybe only
    #   applies to WIN32/MSVC.
    #------------------------------------------------------------------------
    if (MSVC)
        add_compile_definitions("__extension__")
        add_compile_options("/source-charset:utf-8")
        option( USE_STATIC_RUNTIME "Set ON to change /MD(DLL) to /MT(static)" OFF )
        if (USE_STATIC_RUNTIME)
            set(CompilerFlags
                CMAKE_CXX_FLAGS
                CMAKE_CXX_FLAGS_DEBUG
                CMAKE_CXX_FLAGS_RELEASE
                CMAKE_C_FLAGS
                CMAKE_C_FLAGS_DEBUG
                CMAKE_C_FLAGS_RELEASE
                )
            foreach(CompilerFlag ${CompilerFlags})
                string(REPLACE "/MD" "/MT" ${CompilerFlag} "${${CompilerFlag}}")
            endforeach()
            message(STATUS "Using /MT STATIC runtime")
        endif ()
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
