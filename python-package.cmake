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

# Macro to change path files from PARSED_DIRECTORY to the parameter output_dir
macro( get_output_files output_dir )
    foreach( SOURCE_FILE ${${ARGN}} )
        string (REGEX REPLACE "${PARSED_DIRECTORY}" "${ARGV0}" OUTPUT_FILE
                "${SOURCE_FILE}")
        list(APPEND "${ARGN}_OUTPUT" ${OUTPUT_FILE})
    endforeach()
endmacro()

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
#  NAME      the base name for the package
#  DIRECTORY the directory that contains the package sources
#  VERSION   the package version
#  DEPENDS   the targets this package depends on
#  LIBRARIES the libraries to include to the package
#
# Exported variables:
#
#  ${NAME}_WHEEL the corresponding wheel/package name
#  ${NAME}_VERSION the corresponding wheel/package version
#  ${NAME}_WHEEL_PATH the corresponding wheel/package path
#
function(add_python_package)

    # Parse arguments
    set(oneValueArgs NAME DIRECTORY VERSION PYTHON_SOURCE_DIR)
    set(multiValueArgs DEPENDS LIBRARIES)
    cmake_parse_arguments(PARSED "${options}"
                                 "${oneValueArgs}"
                                 "${multiValueArgs}"
                                 ${ARGN})

    if(NOT DEFINED PARSED_PYTHON_SOURCE_DIR )
        set(PARSED_PYTHON_SOURCE_DIR "${PARSED_DIRECTORY}/src")
    ENDIF()

    # We will generate the setup.py based on Cmake configuration variables
    set(SETUP_PY_IN "${PARSED_DIRECTORY}/setup.py.in")
    set(SETUP_PY    "${CMAKE_CURRENT_BINARY_DIR}/setup.py")

    # Explicitly list input files
    file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS "${PARSED_PYTHON_SOURCE_DIR}/*.py")
    file(GLOB LICENSES "${PARSED_DIRECTORY}/LICENSE*")
    file(GLOB READMES "${PARSED_DIRECTORY}/README*")

    # Obtains binary directory filenames that will be stored in new
    # <VARIABLE>_OUTPUT variables
    get_output_files("${CMAKE_CURRENT_BINARY_DIR}/${PARSED_NAME}" SOURCES)
    get_output_files("${CMAKE_CURRENT_BINARY_DIR}" LICENSES)
    get_output_files("${CMAKE_CURRENT_BINARY_DIR}" READMES)

    # Custom command to prepare the directory containing the package files
    # in the build directory
    add_custom_command(
        OUTPUT
            ${CMAKE_CURRENT_BINARY_DIR}/MANIFEST.in
            ${SOURCES_OUTPUT}
            ${LICENSES_OUTPUT}
            ${READMES_OUTPUT}
            ${CMAKE_CURRENT_BINARY_DIR}/${PARSED_NAME}
        # Create target directory
        COMMAND
            ${CMAKE_COMMAND} -E make_directory
                    ${CMAKE_CURRENT_BINARY_DIR}/${PARSED_NAME}
        # Copy source tree
        COMMAND
            ${CMAKE_COMMAND} -E copy_directory ${PARSED_PYTHON_SOURCE_DIR}
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
                ${CMAKE_CURRENT_BINARY_DIR}/${PARSED_NAME}
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
