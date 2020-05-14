# Copyright 2017 Chad Vernon
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
# associated documentation files (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge, publish, distribute,
# sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#.rst:
# FindMaya
# --------
#
# Find Maya headers and libraries.
#
# Imported targets
# ^^^^^^^^^^^^^^^^
#
# This module defines the following :prop_tgt:`IMPORTED` target:
#
# ``Maya::Maya``
#   The Maya libraries, if found.
#
# Result variables
# ^^^^^^^^^^^^^^^^
#
# This module will set the following variables in your project:
#
# ``Maya_FOUND``
#   Defined if a Maya installation has been detected
# ``MAYA_INCLUDE_DIR``
#   Where to find the headers (maya/MFn.h)
# ``MAYA_LIBRARIES``
#   All the Maya libraries.
#

### Locating maya

# Raise an error if Maya version if not specified
if (NOT MAYA_VERSION)
    SET(MAYA_VERSION "VARIABLE_NOT_SET" CACHE STRING "" FORCE)
ENDIF()

if(MAYA_VERSION STREQUAL "VARIABLE_NOT_SET")
    MESSAGE(FATAL_ERROR "MAYA_VERSION variable is not specified")
ENDIF()

# OS Specific environment setup
SET(MAYA_COMPILE_DEFINITIONS "REQUIRE_IOSTREAM;_BOOL")
SET(MAYA_INSTALL_BASE_SUFFIX "")
SET(MAYA_TARGET_TYPE LIBRARY)
if(WIN32)
    # Windows
    SET(MAYA_INSTALL_BASE_DEFAULT "C:/Program Files/Autodesk")
    SET(MAYA_COMPILE_DEFINITIONS "${MAYA_COMPILE_DEFINITIONS};NT_PLUGIN")
    SET(MAYA_PLUGIN_EXTENSION ".mll")
    SET(MAYA_TARGET_TYPE RUNTIME)
elseif(APPLE)
    # Apple
    SET(MAYA_INSTALL_BASE_DEFAULT /Applications/Autodesk)
    SET(MAYA_COMPILE_DEFINITIONS "${MAYA_COMPILE_DEFINITIONS};OSMac_")
    SET(MAYA_PLUGIN_EXTENSION ".bundle")
else()
    # Linux
    SET(MAYA_COMPILE_DEFINITIONS "${MAYA_COMPILE_DEFINITIONS};LINUX")
    SET(MAYA_INSTALL_BASE_DEFAULT /usr/autodesk)
    if(MAYA_VERSION LESS 2016)
        # Pre Maya 2016 on Linux
        SET(MAYA_INSTALL_BASE_SUFFIX -x64)
    ENDIF()
    SET(MAYA_PLUGIN_EXTENSION ".so")
ENDIF()
SET(MAYA_CS_PLUGIN_EXTENSION ".nll.dll")

SET(MAYA_INSTALL_BASE_PATH ${MAYA_INSTALL_BASE_DEFAULT} CACHE STRING
    "Root path containing your maya installations, e.g. /usr/autodesk or /Applications/Autodesk/")

SET(MAYA_LOCATION ${MAYA_INSTALL_BASE_PATH}/maya${MAYA_VERSION}${MAYA_INSTALL_BASE_SUFFIX})

### Setup for C++ plugins

# Maya include directory
find_path(MAYA_INCLUDE_DIR maya/MFn.h
    PATHS
        ${MAYA_LOCATION}
        $ENV{MAYA_LOCATION}
    PATH_SUFFIXES
        "include/"
        "devkit/include/"
)

find_library(MAYA_LIBRARY
    NAMES 
        OpenMaya
    PATHS
        ${MAYA_LOCATION}
        $ENV{MAYA_LOCATION}
    PATH_SUFFIXES
        "lib/"
        "Maya.app/Contents/MacOS/"
    NO_DEFAULT_PATH
)
SET(MAYA_LIBRARIES "${MAYA_LIBRARY}")

INCLUDE(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Maya
    REQUIRED_VARS MAYA_INCLUDE_DIR MAYA_LIBRARY)
MARK_AS_ADVANCED(MAYA_INCLUDE_DIR MAYA_LIBRARY)

IF(NOT TARGET Maya::Maya)
    ADD_LIBRARY(Maya::Maya UNKNOWN IMPORTED)
    SET_TARGET_PROPERTIES(Maya::Maya PROPERTIES
        INTERFACE_COMPILE_DEFINITIONS "${MAYA_COMPILE_DEFINITIONS}"
        INTERFACE_INCLUDE_DIRECTORIES "${MAYA_INCLUDE_DIR}"
        IMPORTED_LOCATION "${MAYA_LIBRARY}")
    
    IF(APPLE AND ${CMAKE_CXX_COMPILER_ID} MATCHES "Clang" AND MAYA_VERSION LESS 2017)
        # Clang and Maya 2016 and older needs to use libstdc++
        SET_TARGET_PROPERTIES(Maya::Maya PROPERTIES
            INTERFACE_COMPILE_OPTIONS "-std=c++0x;-stdlib=libstdc++")
    ENDIF()
ENDIF()

# Add the other Maya libraries into the main Maya::Maya library
SET(_MAYA_LIBRARIES OpenMayaAnim OpenMayaFX OpenMayaRender OpenMayaUI Foundation clew)
FOREACH(MAYA_LIB ${_MAYA_LIBRARIES})
    find_library(MAYA_${MAYA_LIB}_LIBRARY
        NAMES 
            ${MAYA_LIB}
        PATHS
            ${MAYA_LOCATION}
            $ENV{MAYA_LOCATION}
        PATH_SUFFIXES
            "lib/"
            "Maya.app/Contents/MacOS/"
        NO_DEFAULT_PATH)
    mark_as_advanced(MAYA_${MAYA_LIB}_LIBRARY)
    if (MAYA_${MAYA_LIB}_LIBRARY)
        ADD_LIBRARY(Maya::${MAYA_LIB} UNKNOWN IMPORTED)
        SET_TARGET_PROPERTIES(Maya::${MAYA_LIB} PROPERTIES
            IMPORTED_LOCATION "${MAYA_${MAYA_LIB}_LIBRARY}")
        SET_PROPERTY(TARGET Maya::Maya APPEND PROPERTY
            INTERFACE_LINK_LIBRARIES Maya::${MAYA_LIB})
        SET(MAYA_LIBRARIES ${MAYA_LIBRARIES} "${MAYA_${MAYA_LIB}_LIBRARY}")
    ENDIF()
endforeach()

### Setup for C# Plugins
SET(
    _MAYA_OPENMAYA_ASSEMBLY
    ${MAYA_LOCATION}/bin/openmayacs.dll
)
ADD_LIBRARY(
    Maya::MayaCS SHARED IMPORTED
)
SET_TARGET_PROPERTIES(Maya::MayaCS PROPERTIES
    LINKER_LANGUAGE CSharp
    VS_DOTNET_TARGET_FRAMEWORK_VERSION CMAKE_DOTNET_TARGET_FRAMEWORK_VERSION
    VS_DOTNET_REFERENCES 
        ${_MAYA_OPENMAYA_ASSEMBLY}
)

### binding functions

# todo auto install
# make install an setup variable option
function(MAYA_PLUGIN _target)
    if (WIN32)
        SET_TARGET_PROPERTIES(${_target} PROPERTIES
            LINK_FLAGS "/export:initializePlugin /export:uninitializePlugin")
    ENDIF()
    SET_TARGET_PROPERTIES(${_target} PROPERTIES
        PREFIX ""
        SUFFIX ${MAYA_PLUGIN_EXTENSION})
endfunction()

# Maya plugin specific drop-in replacement for ADD_LIBRARY command
function(ADD_MAYA_PLUGIN_ENTRY _target)
    ADD_LIBRARY(${_target} SHARED)
    MAYA_PLUGIN(${_target})
endfunction()

function(MAYA_CS_PLUGIN _target)
    SET_TARGET_PROPERTIES(
        ${_target}
        PROPERTIES
        VS_DOTNET_REFERENCES_COPY_LOCAL OFF
        SUFFIX ${MAYA_CS_PLUGIN_EXTENSION}
    )
    SET_PROPERTY(
        TARGET ${_target} APPEND
        PROPERTY
        VS_DOTNET_REFERENCES
            "System"
            "System.Core"
            "System.Xml"
            "System.Xml.Linq"
            ${_MAYA_OPENMAYA_ASSEMBLY}
    )
endfunction()