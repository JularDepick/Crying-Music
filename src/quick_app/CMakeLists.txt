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

find_package(Qt6 REQUIRED COMPONENTS Quick Multimedia Qml Network Widgets)

# TagLib: 读取本地音频的标签, 内嵌封面与歌词(第三方静态库, 许可见 THIRD-PARTY-NOTICES.md).
# 默认使用随源码携带的预构建产物 external/taglib, 因此从源码构建只需要装 Qt, 不必另外安装 TagLib;
# 想用自己编译的那份时传 -DTAGLIB_ROOT=<安装前缀>, 布局与随源码携带的一致(include/ 与 lib/);
# 该库是静态库, 运行时不需要额外的 DLL, 静态链接时需要 zlib(由 MinGW 工具链自带)
set(TAGLIB_ROOT "" CACHE PATH "外部 TagLib 安装前缀, 留空表示使用随源码携带的 external/taglib")
set(TAGLIB_VENDORED_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/external/taglib")
if(TAGLIB_ROOT)
    set(TAGLIB_EFFECTIVE_ROOT "${TAGLIB_ROOT}")
else()
    set(TAGLIB_EFFECTIVE_ROOT "${TAGLIB_VENDORED_ROOT}")
    if(NOT MINGW)
        message(WARNING "随源码携带的 TagLib 静态库是 MinGW 64 位构建的; 当前不是 MinGW 工具链, 请用 -DTAGLIB_ROOT 指定自己编译的安装前缀")
    endif()
endif()
list(APPEND CMAKE_PREFIX_PATH "${TAGLIB_EFFECTIVE_ROOT}")
if(POLICY CMP0144)
    cmake_policy(SET CMP0144 NEW)
endif()
find_package(TagLib CONFIG REQUIRED)
message(STATUS "TagLib 安装前缀: ${TAGLIB_EFFECTIVE_ROOT}")
# zlib: TagLib 的静态库会引用 zlib 的符号, 由 MinGW 工具链自带(x86_64-w64-mingw32/lib/libz.a),
# 直接在链接行写 z, 让链接器按自己的搜索路径去找, 不走 find_library

# 业务逻辑源文件
file(GLOB_RECURSE COMPONENTS_SOURCES CONFIGURE_DEPENDS "components/*.hpp")

set(PROJECT_SOURCES
    main.cpp
    defines.hpp
    resource.rc
    resource.qrc
    ${COMPONENTS_SOURCES}
)

# 可执行目标
qt_add_executable(CryingMusic
    MANUAL_FINALIZATION
    ${PROJECT_SOURCES}
)

# 收集 QML 文件
file(GLOB QML_ROOT CONFIGURE_DEPENDS RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}/*.qml")
file(GLOB_RECURSE QML_SUBDIR CONFIGURE_DEPENDS RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}/qml/*.qml")
set(ALL_QML_FILES ${QML_ROOT} ${QML_SUBDIR})
# 标记单例
set_source_files_properties(qml/Define.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/GlobalFileStorage.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/Assist.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/Server.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/Account.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
# 创建 QML 模块;RESOURCE_PREFIX "/" 与 NO_RESOURCE_TARGET_PATH 使 QML 文件
# 按源码相对路径嵌入,如 qrc:/Main.qml、qrc:/qml/Define.qml,与 main.cpp 入口一致
qt_policy(SET QTP0004 NEW)
qt_add_qml_module(CryingMusic
    URI CryingMusic
    VERSION 1.0
    RESOURCE_PREFIX /
    NO_RESOURCE_TARGET_PATH
    QML_FILES ${ALL_QML_FILES}
    # SOURCES components/*.hpp
)

# 预编译头
target_precompile_headers(CryingMusic PRIVATE defines.hpp)

# Windows 资源文件处理
if(MINGW)
    set_source_files_properties(resource.rc PROPERTIES LANGUAGE RC)
endif()

# 链接库
target_link_libraries(CryingMusic
    PRIVATE Qt6::Quick Qt6::Multimedia Qt6::Qml Qt6::Network Qt6::Widgets
            TagLib::TagLib z
)

# 静态链接 MinGW 运行时
if(MINGW)
    target_link_options(CryingMusic PRIVATE -static-libgcc -static-libstdc++)
endif()

# Windows 属性
set_target_properties(CryingMusic PROPERTIES
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
)

install(TARGETS CryingMusic
    BUNDLE  DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

qt_finalize_executable(CryingMusic)

# 自动部署 DLL
if(WIN32)
    find_program(WINDEPLOYQT_EXECUTABLE windeployqt6)
    if(WINDEPLOYQT_EXECUTABLE)
        add_custom_command(TARGET CryingMusic POST_BUILD
            COMMAND ${WINDEPLOYQT_EXECUTABLE}
                --no-system-d3d-compiler
                --qmldir ${CMAKE_CURRENT_SOURCE_DIR}
                $<TARGET_FILE:CryingMusic>
            COMMENT "复制 Qt6 依赖 DLL..."
        )
    else()
        message(WARNING "未找到 windeployqt，请手动部署。")
    endif()
endif()