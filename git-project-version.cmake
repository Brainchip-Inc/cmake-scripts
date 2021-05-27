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

# Parses the result of git describe an extracts the project version from
# the latest tag.
# Note: the tag is expected to be in the form vX.Y.Z
#
# Example:
#  GIT_PROJECT_VERSION       : v1.2.0-282-g93f8b4a6
#  GIT_PROJECT_VERSION_MAJOR : 1
#  GIT_PROJECT_VERSION_MINOR : 2
#  GIT_PROJECT_VERSION_PATCH : 0
#  GIT_PROJECT_VERSION_BASE  : 1.2.0
#  GIT_PROJECT_VERSION_MICRO : 282
#  GIT_PROJECT_VERSION_SHA   : 93f8b4a6

find_package(Git QUIET REQUIRED)

execute_process(
    COMMAND "${GIT_EXECUTABLE}" describe --tags --always HEAD
    WORKING_DIRECTORY "${GIT_PROJECT_ROOT_DIR}"
    RESULT_VARIABLE res
    OUTPUT_VARIABLE GIT_PROJECT_VERSION
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE)

set_property(GLOBAL APPEND
    PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${GIT_PROJECT_ROOT_DIR}/.git/index")

if("${GIT_PROJECT_VERSION}" MATCHES "^.*-(.*)-(.*)$")
    set(GIT_VERSION_AVAILABLE ON)
    # Expected tag format is vX.Y.Z
    string(REGEX REPLACE "^([0-9]+)\\.([0-9]+)\\.([0-9]+).*$"
    "\\1;\\2;\\3" _ver_parts "${GIT_PROJECT_VERSION}")
    list(GET _ver_parts 0 GIT_PROJECT_VERSION_MAJOR)
    list(GET _ver_parts 1 GIT_PROJECT_VERSION_MINOR)
    list(GET _ver_parts 2 GIT_PROJECT_VERSION_PATCH)

    set(GIT_PROJECT_VERSION_BASE
        "${GIT_PROJECT_VERSION_MAJOR}.${GIT_PROJECT_VERSION_MINOR}.${GIT_PROJECT_VERSION_PATCH}")

    if("${GIT_PROJECT_VERSION}" MATCHES "^.*-(.*)-g(.*)$")
        string(REGEX REPLACE "^.*-(.*)-g(.*)$" "\\1;\\2" _patch_parts
            "${GIT_PROJECT_VERSION}")
        list(GET _patch_parts 0 GIT_PROJECT_VERSION_MICRO)
        list(GET _patch_parts 1 GIT_PROJECT_VERSION_SHA)
    else()
        set(GIT_PROJECT_VERSION_MICRO "0")
    endif()
else()
    set(GIT_VERSION_AVAILABLE OFF)
endif()
