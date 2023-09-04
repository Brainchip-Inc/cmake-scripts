#
# Copyright 2021, BrainChip Holdings Ltd. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

# These paths need to be set a configuration time, because they are used inside
# the add_python_package method that is called from a different source directory
set(WHEEL_NAME_CMD ${CMAKE_CURRENT_LIST_DIR}/bdist_wheel_name.py)
set(BDIST_WHEEL_IN ${CMAKE_CURRENT_LIST_DIR}/bdist_wheel.in)
set(SDIST_IN ${CMAKE_CURRENT_LIST_DIR}/sdist.in)

if (PYTHON_CROSS_PLATFORM_NAME)
    set(BDIST_WHEEL_OPTIONS "--plat-name ${PYTHON_CROSS_PLATFORM_NAME}")
endif()

# Replace the specified list of source directories by target directory in files
function(get_output_files)
    # Parse arguments
    set(oneValueArgs DST_DIR OUTPUT_VAR)
    set(multiValueArgs SRC_DIRS SRC_FILES)
    cmake_parse_arguments(PARSED "${options}"
                                 "${oneValueArgs}"
                                 "${multiValueArgs}"
                                 ${ARGN})
    # Initialize output variable with input sources
    set(DST_FILES ${PARSED_SRC_FILES})
    foreach(SRC_DIR IN LISTS PARSED_SRC_DIRS)
        list(TRANSFORM DST_FILES REPLACE ${SRC_DIR} ${PARSED_DST_DIR})
    endforeach()
    # Cmake functions cannot return values: Set output variable in parent scope
    set(${PARSED_OUTPUT_VAR} ${DST_FILES} PARENT_SCOPE)
endfunction()

# Macro to change path libraries to CMAKE_CURRENT_BINARY_DIR
macro( get_output_libs )
    foreach( SOURCE_FILE ${${ARGN}} )
        get_filename_component(OUTPUT_FILE "${SOURCE_FILE}" NAME)
        set(OUTPUT_FILE "${CMAKE_CURRENT_BINARY_DIR}/${PARSED_NAME}/${OUTPUT_FILE}")
        list(APPEND "${ARGN}_OUTPUT" ${OUTPUT_FILE})
    endforeach()
endmacro()

# Add a target to build a python package
#
# The package root source directory must contain:
# - an 'src' directory where that contains the package python files
# - a setup.py.in template for setup.py,
# - a MANIFEST.in file,
# - one or several LICENSE files,
# - one or several README files.
#
# Args:
#  NAME        the base name for the package
#  DIRECTORY   the directory that contains the package setup files
#  VERSION     the package version
#  DEPENDS     the targets this package depends on
#  SOURCE_DIRS the package source directories
#  LIBRARIES   the libraries to include to the package
#  VENV_DIR    the path to the virtual environment to use to build the package
#
# Exported variables:
#
#  ${NAME}_WHEEL the corresponding wheel/package name
#  ${NAME}_VERSION the corresponding wheel/package version
#  ${NAME}_WHEEL_PATH the corresponding wheel/package path
#
function(add_python_package)

    # Parse arguments
    set(oneValueArgs NAME DIRECTORY VERSION VENV_DIR)
    set(multiValueArgs SOURCE_DIRS DEPENDS LIBRARIES)
    cmake_parse_arguments(PARSED "${options}"
                                 "${oneValueArgs}"
                                 "${multiValueArgs}"
                                 ${ARGN})

    if(NOT DEFINED PARSED_SOURCE_DIRS )
        set(PARSED_SOURCE_DIRS "${PARSED_DIRECTORY}/src")
    ENDIF()

    # We will generate the setup.py based on Cmake configuration variables
    set(SETUP_PY_IN "${PARSED_DIRECTORY}/setup.py.in")
    set(SETUP_PY    "${CMAKE_CURRENT_BINARY_DIR}/setup.py")

    # Explicitly list input files
    list(TRANSFORM PARSED_SOURCE_DIRS APPEND "/*.*" OUTPUT_VARIABLE GLOB_SOURCES)
    file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS ${GLOB_SOURCES})
    file(GLOB LICENSES "${PARSED_DIRECTORY}/LICENSE*")
    file(GLOB READMES "${PARSED_DIRECTORY}/README*")

    # Evaluate the output files corresponding to files from source directories
    get_output_files(
        DST_DIR
            "${CMAKE_CURRENT_BINARY_DIR}/${PARSED_NAME}"
        SRC_DIRS
            "${PARSED_SOURCE_DIRS}"
        SRC_FILES
            "${SOURCES}"
        OUTPUT_VAR
            SOURCES_OUTPUT
    )
    # Evaluate the output files corresponding to files in the current directory
    get_output_files(
        DST_DIR
            "${CMAKE_CURRENT_BINARY_DIR}"
        SRC_DIRS
            "${CMAKE_CURRENT_SOURCE_DIR}"
        SRC_FILES
            "${LICENSES}"
            "${READMES}"
        OUTPUT_VAR
            OTHERS_OUTPUT
    )

    # Custom command to prepare the directory containing the package files
    # in the build directory
    add_custom_command(
        OUTPUT
            ${CMAKE_CURRENT_BINARY_DIR}/MANIFEST.in
            ${SOURCES_OUTPUT}
            ${OTHERS_OUTPUT}
            ${CMAKE_CURRENT_BINARY_DIR}/${PARSED_NAME}
        # Create target directory
        COMMAND
            ${CMAKE_COMMAND} -E make_directory
                    ${CMAKE_CURRENT_BINARY_DIR}/${PARSED_NAME}
        # Copy source directories contents at the root of the package
        COMMAND
            ${CMAKE_COMMAND} -E copy_directory ${PARSED_SOURCE_DIRS}
                    ${CMAKE_CURRENT_BINARY_DIR}/${PARSED_NAME}
        # Copy manifest
        COMMAND
            ${CMAKE_COMMAND} -E copy ${PARSED_DIRECTORY}/MANIFEST.in
                    ${CMAKE_CURRENT_BINARY_DIR}
        # Copy license file(s)
        COMMAND
            ${CMAKE_COMMAND} -E copy ${LICENSES} ${CMAKE_CURRENT_BINARY_DIR}
        # Copy README file(s)
        COMMAND
            ${CMAKE_COMMAND} -E copy ${READMES} ${CMAKE_CURRENT_BINARY_DIR}
        DEPENDS
            ${PARSED_DIRECTORY}/MANIFEST.in
            "${LICENSES}"
            "${READMES}"
            "${SOURCES}"
            "${PARSED_DEPENDS}"
    )

    # Generate setup script from template
    configure_file(${SETUP_PY_IN} ${SETUP_PY})

    if (PARSED_LIBRARIES) # Binary distribution

        # Evaluate wheel name
        execute_process(
            COMMAND ${PYTHON_EXECUTABLE} ${WHEEL_NAME_CMD}
              -n ${PARSED_NAME} -v ${PARSED_VERSION} ${BDIST_WHEEL_OPTIONS}
            OUTPUT_VARIABLE WHEEL_NAME
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )

        set(WHEEL_PATH "${CMAKE_CURRENT_BINARY_DIR}/dist/${WHEEL_NAME}")

        # Obtains binary directory libraries that will be stored in new
        # PARSED_LIBRARIES_OUTPUT variable
        get_output_libs(PARSED_LIBRARIES)

        # Add a custom command to copy libraries
        add_custom_command(
            OUTPUT
                ${PARSED_LIBRARIES_OUTPUT}
            COMMAND
                ${CMAKE_COMMAND} -E copy
                        ${PARSED_LIBRARIES}
                        ${CMAKE_CURRENT_BINARY_DIR}/${PARSED_NAME}
            DEPENDS
                ${PARSED_LIBRARIES}
        )

        # Add a custom target to generate the wheel inside a virtual environment
        add_venv_target(
            NAME
                ${PARSED_NAME}_wheel
            OUTPUT
                ${WHEEL_PATH}
            ALL
            COMMAND_SCRIPT_IN
                ${BDIST_WHEEL_IN}
            VENV_DIR
                ${PARSED_VENV_DIR}
            WORKING_DIRECTORY
                ${CMAKE_CURRENT_BINARY_DIR}
            DEPENDS
                ${CMAKE_CURRENT_BINARY_DIR}/MANIFEST.in
                ${SOURCES_OUTPUT}
                ${LICENSES_OUTPUT}
                ${READMES_OUTPUT}
                ${PARSED_LIBRARIES_OUTPUT}
        )

    else () # Source distribution

        set(WHEEL_NAME
            "${PARSED_NAME}-${PARSED_VERSION}.tar.gz")

        set(WHEEL_PATH "${CMAKE_CURRENT_BINARY_DIR}/dist/${WHEEL_NAME}")

        # Add a custom target to generate the wheel inside a virual environment
        add_venv_target(
            NAME
                ${PARSED_NAME}_wheel
            OUTPUT
                ${WHEEL_PATH}
            ALL
            COMMAND_SCRIPT_IN
                ${SDIST_IN}
            WORKING_DIRECTORY
                ${CMAKE_CURRENT_BINARY_DIR}
            VENV_DIR
                ${PARSED_VENV_DIR}
            DEPENDS
                ${CMAKE_CURRENT_BINARY_DIR}/MANIFEST.in
                ${SOURCES_OUTPUT}
                ${LICENSES_OUTPUT}
                ${READMES_OUTPUT}
        )

    endif ()

    install(FILES ${WHEEL_PATH}
            DESTINATION pip)

    # Export the python package variables
    set(${PARSED_NAME}_VERSION ${PARSED_VERSION} PARENT_SCOPE)
    set(${PARSED_NAME}_WHEEL ${WHEEL_NAME} PARENT_SCOPE)
    set(${PARSED_NAME}_WHEEL_PATH ${WHEEL_PATH} PARENT_SCOPE)

endfunction()
