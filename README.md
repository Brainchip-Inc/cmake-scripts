# Brainchip Software Development Team cmake scripts

A collection of `cmake` scripts used in C++ and python development projects.

To include these files in your project, we recommend using `cmake` `FetchContent`.

Typically, create a `cmake-scripts.cmake` as follows:

````
include(FetchContent)

FetchContent_Declare(
    cmake-scripts
    GIT_REPOSITORY  "https://github.com/Brainchip-Inc/cmake-scripts.git"
    GIT_TAG "0.1"
    GIT_PROGRESS ON
    )

FetchContent_GetProperties(cmake-scripts)

if(NOT cmake-scripts_POPULATED)
    FetchContent_Populate(cmake-scripts)
    list(APPEND CMAKE_MODULE_PATH "${cmake-scripts_SOURCE_DIR}")
endif()
````

Then include it in your `CMakeLists.txt`:

````
project(foo)

cmake_minimum_required(VERSION 3.13)

# Import common cmake scripts
include(cmake-scripts)

# Extract version from git
include(git-project-version)
````

Unless mentioned otherwise in the file header, all scripts are licensed under
the Apache 2.0 License.

**Copyright 2021, BrainChip Holdings Ltd. All rights reserved.**
