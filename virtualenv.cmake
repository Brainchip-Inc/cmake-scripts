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

# Create a reference to the venv command wrapper template
set(VENV_WRAPPER_IN ${CMAKE_CURRENT_LIST_DIR}/venv_wrapper.in)

execute_process(COMMAND "${PYTHON_EXECUTABLE}" -c "import virtualenv" RESULT_VARIABLE ret_virtualenv)

# Custom method to add a target that must be built using a command script run
# in its own virtualenv.
# The command script must be provided as a script template that will be passed
# to the cmake configure_file method for substitutions.
# The parameters are:
# - the target NAME,
# - the path to the command script template,
# - the command working directory,
# - the path to the virtual env (defaults to CURRENT_BINARY_DIR/NAME_venv),
# - a list of target dependencies,
# - a flag to indicate if the target must be added to 'all'.
#
# The script works on both unix and Windows, with some caveats for the script
# template: if the target is expected to return a value, it must be specified
# explicitly at the end of the script template using the provided SCRIPT_RET
# variable that contains the return value of the last shell command, because
# Windows ps1 scripts do not return it automatically.
#
# Example:
# add_venv_target(
#     NAME
#         pytest
#     COMMAND_SCRIPT_IN
#         ${CMAKE_CURRENT_SOURCE_DIR}/pytest.in
#     WORKING_DIRECTORY
#         ${CMAKE_CURRENT_SOURCE_DIR}
#     DEPENDS
#         <some-package>
# )
#
# pytest.in:
#  pip install pytest
#  pip install <some-package>
#  pytest -v .
#  exit ${SCRIPT_RET}
#
function(add_venv_target)

    # Parse arguments
    set(options ALL)
    set(oneValueArgs NAME COMMAND_SCRIPT_IN WORKING_DIRECTORY VENV_DIR)
    set(multiValueArgs DEPENDS OUTPUT)
    cmake_parse_arguments(PARSED "${options}"
                                 "${oneValueArgs}"
                                 "${multiValueArgs}"
                                 ${ARGN})

    if (NOT ret_virtualenv EQUAL "0")
        message(FATAL_ERROR "Could not find python module `virtualenv`, required by ${PARSED_NAME}")
    endif()

    #######################################################
    # Create a custom command to generate the virtual env #
    #######################################################

    set(VENV_DIR ${PARSED_VENV_DIR})

    if(NOT VENV_DIR)
        set(VENV_NAME ${PARSED_NAME}_venv)
        set(VENV_DIR ${CMAKE_CURRENT_BINARY_DIR}/${VENV_NAME})
    else()
        get_filename_component(VENV_NAME ${VENV_DIR} NAME)
    endif()

    set(VENV_TARGET gen_${VENV_NAME})

    if(NOT TARGET ${VENV_TARGET})
        # Create a custom target for the virtual env directory
        add_custom_target(${VENV_TARGET}
        DEPENDS
            ${VENV_DIR}
        )
    endif()

    # Create a custom command to create the virtual env
    add_custom_command(
        OUTPUT
            ${VENV_DIR}
        COMMAND
            ${PYTHON_EXECUTABLE} -m virtualenv -p ${PYTHON_EXECUTABLE} ${VENV_DIR}
    )

    ###################################
    # Generate wrapped command script #
    ###################################

    # First define some platform variables for substitution
    if (WIN32)
        set(SCRIPT_RUNNER PowerShell)
        set(SCRIPT_EXT ps1)
        set(SCRIPT_RET $lastexitcode)
        set(VENV_ACTIVATE Scripts/activate.ps1)
    else ()
        set(SCRIPT_RUNNER bash)
        set(SCRIPT_EXT sh)
        set(SCRIPT_RET $?)
        set(VENV_ACTIVATE bin/activate)
    endif()
    # Define the platform-specific command script name
    set(VENV_COMMAND_SCRIPT
        ${CMAKE_CURRENT_BINARY_DIR}/${PARSED_NAME}_venv_cmd.${SCRIPT_EXT})
    # Substitute variables into command template
    configure_file(${PARSED_COMMAND_SCRIPT_IN} ${VENV_COMMAND_SCRIPT})
    # Define the platform-specific venv wrapper script name
    set(VENV_WRAPPER_SCRIPT
        ${CMAKE_CURRENT_BINARY_DIR}/${PARSED_NAME}_venv_wrapper.${SCRIPT_EXT})
    # Substitute variables into wrapper template
    configure_file(${VENV_WRAPPER_IN} ${VENV_WRAPPER_SCRIPT})


    #########################################################
    # Create a custom target that uses the generated script #
    #########################################################

    # Check if we need to add this to the ALL target
    if (${PARSED_ALL})
        set(ALL_TARGET ALL)
    endif()

    if (PARSED_OUTPUT)
        # If OUTPUT is defined, we use add_custom_command + add_custom_target,
        # to avoid running virtual env script everytime
        add_custom_command(
            OUTPUT
                ${PARSED_OUTPUT}
            COMMAND
                ${SCRIPT_RUNNER} ${VENV_WRAPPER_SCRIPT}
            WORKING_DIRECTORY
                ${PARSED_WORKING_DIRECTORY}
            DEPENDS
                ${VENV_TARGET}
                "${PARSED_DEPENDS}"
            USES_TERMINAL
        )
        add_custom_target(${PARSED_NAME} ${ALL_TARGET}
            DEPENDS
                ${PARSED_OUTPUT}
        )
    else()
        # Without OUTPUT, we can only use add_custom_target, that means virtual
        # env script will be run everytime the target is called
        add_custom_target(${PARSED_NAME} ${ALL_TARGET}
            COMMAND
                ${SCRIPT_RUNNER} ${VENV_WRAPPER_SCRIPT}
            WORKING_DIRECTORY
                ${PARSED_WORKING_DIRECTORY}
            DEPENDS
                ${VENV_TARGET}
                "${PARSED_DEPENDS}"
            USES_TERMINAL
        )
    endif()

endfunction()
