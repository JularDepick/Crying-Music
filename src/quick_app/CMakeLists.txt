# 最低CMake版本
cmake_minimum_required(VERSION 3.16)

# 项目名称和版本号
project(CryingMusic VERSION 0.1.0 LANGUAGES CXX)

# C++和Qt标准
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Qt自动化工具
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Multimedia)

# 业务逻辑源文件
file(GLOB_RECURSE CORE_SOURCES "core/*.cpp" "core/*.h")

set(PROJECT_SOURCES
    main.cpp
    defines.hpp
    resource.rc
    ${CORE_SOURCES}
)

# 可执行目标
qt_add_executable(appCryingMusic
    MANUAL_FINALIZATION
    ${PROJECT_SOURCES}
)

# 将 Main.qml 直接嵌入资源
qt_add_resources(appCryingMusic "qml_resources"
    PREFIX "/"
    FILES Main.qml
)

# 预编译头
target_precompile_headers(appCryingMusic PRIVATE defines.hpp)

# Windows 资源文件处理
if(MINGW)
    set_source_files_properties(resource.rc PROPERTIES LANGUAGE RC)
endif()

# 链接库
target_link_libraries(appCryingMusic
    PRIVATE Qt6::Quick Qt6::Multimedia
)

# 静态链接 MinGW 运行时
if(MINGW)
    target_link_options(appCryingMusic PRIVATE -static-libgcc -static-libstdc++)
endif()

# Windows 属性
set_target_properties(appCryingMusic PROPERTIES
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
)

install(TARGETS appCryingMusic
    BUNDLE  DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

qt_finalize_executable(appCryingMusic)

# 自动部署 DLL
if(WIN32)
    find_program(WINDEPLOYQT_EXECUTABLE windeployqt6)
    if(WINDEPLOYQT_EXECUTABLE)
        add_custom_command(TARGET appCryingMusic POST_BUILD
            COMMAND ${WINDEPLOYQT_EXECUTABLE}
                --no-system-d3d-compiler
                --qmldir ${CMAKE_SOURCE_DIR}
                $<TARGET_FILE:appCryingMusic>
            COMMENT "复制 Qt6 依赖 DLL..."
        )
    else()
        message(WARNING "未找到 windeployqt，请手动部署。")
    endif()
endif()