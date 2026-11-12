# alpbahOS Hoş Geldin (WELCOME-01, D121). Built in the r4-root chroot (Qt 6 under /opt/qt6) as an alp package.
cmake_minimum_required(VERSION 3.21)
project(alpbah-hosgeldin VERSION 0.9 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Widgets)
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(alpbah-hosgeldin main.cpp)
qt_add_qml_module(alpbah-hosgeldin
    URI AlpbahHosgeldin
    VERSION 1.0
    QML_FILES Main.qml Mantik.qml Dugme.qml Segment.qml
    RESOURCES mark.png
)
target_link_libraries(alpbah-hosgeldin PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Widgets)
install(TARGETS alpbah-hosgeldin RUNTIME DESTINATION bin)
