# YUNSH OS Compositor CMakeLists
cmake_minimum_required(VERSION 3.20)
project(yunsh-compositor LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find dependencies
find_package(PkgConfig REQUIRED)

# DRM
pkg_check_modules(DRM REQUIRED libdrm)
# EGL
pkg_check_modules(EGL REQUIRED egl)
# GLES3
pkg_check_modules(GLES3 REQUIRED glesv2)
# libinput
pkg_check_modules(LIBINPUT REQUIRED libinput)
# udev
pkg_check_modules(UDEV REQUIRED libudev)

# Source files
set(SOURCES
    main.cpp
    compositor.cpp
)

# Include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${DRM_INCLUDE_DIRS}
    ${EGL_INCLUDE_DIRS}
    ${GLES3_INCLUDE_DIRS}
    ${LIBINPUT_INCLUDE_DIRS}
    ${UDEV_INCLUDE_DIRS}
)

# Link libraries
target_link_libraries(yunsh-compositor
    ${DRM_LIBRARIES}
    ${EGL_LIBRARIES}
    ${GLES3_LIBRARIES}
    ${LIBINPUT_LIBRARIES}
    ${UDEV_LIBRARIES}
    pthread
    dl
)

# Build executable
add_executable(yunsh-compositor ${SOURCES})

# Install
install(TARGETS yunsh-compositor RUNTIME DESTINATION /usr/bin)
