# Образ lowlevel для робота jetbot_mirea: ROS2 Humble + CycloneDDS 0.10.x + репозиторий.
# Железо: Jetson Nano (arm64), хост Ubuntu 20.04 (L4T R32.6.1), Docker 26.
# Контекст сборки — эта папка; репозиторий должен лежать рядом, в ./src

ARG BASE_IMAGE=ros:humble-ros-base
FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG WITH_NAV2=0
ARG BUILD_JOBS=2
ARG USER_UID=1000
ARG USER_GID=1000
ARG USERNAME=ros
# Пакеты репозитория, которые на роботе не нужны (Gazebo, Nav2-клиент, Tk-GUI)
ARG COLCON_SKIP="realsense_ros_gazebo trajectory_maker simple_regulators_configurator_pkg"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    RMW_IMPLEMENTATION=rmw_cyclonedds_cpp \
    CYCLONEDDS_URI=file:///etc/cyclonedds/cyclonedds.xml

# --- 1. Системные и ROS-пакеты ------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake git sudo bash-completion nano vim neovim ranger htop \
        iproute2 iputils-ping net-tools iperf3 tcpdump usbutils v4l-utils \
        python3-pip python3-serial python3-colcon-common-extensions \
        ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
        ros-${ROS_DISTRO}-realsense2-camera \
        ros-${ROS_DISTRO}-compressed-image-transport \
        ros-${ROS_DISTRO}-tf2-ros \
        ros-${ROS_DISTRO}-teleop-twist-keyboard \
        ros-${ROS_DISTRO}-xacro \
        ros-${ROS_DISTRO}-robot-state-publisher \
        ros-${ROS_DISTRO}-joint-state-publisher \
        ros-${ROS_DISTRO}-demo-nodes-cpp \
    && if [ "${WITH_NAV2}" = "1" ]; then \
         apt-get install -y --no-install-recommends \
           ros-${ROS_DISTRO}-navigation2 \
           ros-${ROS_DISTRO}-nav2-bringup \
           ros-${ROS_DISTRO}-slam-toolbox; \
       fi \
    && rm -rf /var/lib/apt/lists/*

# --- 2. Пользователь (без root) с доступом к железу -----------------------------
RUN set -ex; \
    getent group "${USER_GID}" >/dev/null || groupadd -g "${USER_GID}" "${USERNAME}"; \
    getent passwd "${USER_UID}" >/dev/null || useradd -m -u "${USER_UID}" -g "${USER_GID}" -s /bin/bash "${USERNAME}"; \
    U="$(getent passwd "${USER_UID}" | cut -d: -f1)"; \
    usermod -aG sudo,video,dialout,plugdev "${U}"; \
    echo "${U} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-lowlevel; \
    chmod 0440 /etc/sudoers.d/90-lowlevel; \
    mkdir -p /ws /etc/cyclonedds; \
    chown "${USER_UID}:${USER_GID}" /ws

# --- 3. Скрипты и конфиг DDS ---------------------------------------------------
COPY files/ros_entrypoint.sh /ros_entrypoint.sh
COPY files/bashrc_extra.sh /usr/local/share/jetbot_bashrc.sh
COPY cyclonedds.xml /etc/cyclonedds/cyclonedds.xml
RUN chmod 0755 /ros_entrypoint.sh

# --- 4. Репозиторий и сборка ---------------------------------------------------
USER ${USER_UID}:${USER_GID}
WORKDIR /ws
COPY --chown=${USER_UID}:${USER_GID} src/ /ws/src/

RUN set -ex; \
    for p in ${COLCON_SKIP}; do \
        if [ -d "src/${p}" ]; then touch "src/${p}/COLCON_IGNORE"; fi; \
    done; \
    source /opt/ros/${ROS_DISTRO}/setup.bash; \
    MAKEFLAGS="-j${BUILD_JOBS}" colcon build \
        --parallel-workers "${BUILD_JOBS}" \
        --cmake-args -DCMAKE_BUILD_TYPE=Release \
        --event-handlers console_cohesion+; \
    rm -rf /ws/build

# --- 4b. Хук окружения jetbot_mirea_description требует Gazebo, которого в образе нет ---
RUN find /ws/install -name 'jetbot_mirea_description_model_path.sh' -exec \
        sed -i 's|^source /usr/share/gazebo/setup.sh$|if [ -f /usr/share/gazebo/setup.sh ]; then . /usr/share/gazebo/setup.sh; fi|' {} +

# --- 5. Проверка сборки (образ не соберётся, если чего-то нет) -------------------
RUN set -ex; \
    source /opt/ros/${ROS_DISTRO}/setup.bash; \
    source /ws/install/setup.bash; \
    for p in serial_bridge_package sllidar_ros2 lidar_filter realsense_pkg \
             completed_scripts_jetbot jetbot_mirea_description \
             realsense2_camera rmw_cyclonedds_cpp; do \
        ros2 pkg prefix "$p"; \
    done; \
    dpkg-query -W 'ros-*-cyclonedds' || true

RUN echo 'source /usr/local/share/jetbot_bashrc.sh' >> "${HOME:-/home/${USERNAME}}/.bashrc"

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]
