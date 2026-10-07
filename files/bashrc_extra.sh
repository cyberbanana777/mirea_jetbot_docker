# Подключается из ~/.bashrc пользователя контейнера (только интерактивные оболочки).
if [ -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]; then source "/opt/ros/${ROS_DISTRO}/setup.bash"; fi
if [ -f /ws/install/setup.bash ]; then source /ws/install/setup.bash; fi
if [ -f /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash ]; then
    source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash
fi
if command -v register-python-argcomplete3 >/dev/null 2>&1; then
    eval "$(register-python-argcomplete3 ros2 2>/dev/null)" || true
fi

export PS1='\[\e[1;32m\]\u\[\e[0m\]@\[\e[1;36m\]jetbot-ros2\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
alias ll='ls -alF --color=auto'
alias cb='cd /ws && colcon build --parallel-workers 2 --cmake-args -DCMAKE_BUILD_TYPE=Release'

jetbot_banner() {
    local ok='\e[32m[ok]\e[0m' no='\e[31m[--]\e[0m'
    echo -e "\e[1mjetbot_mirea · lowlevel\e[0m   ROS2 ${ROS_DISTRO} · ${RMW_IMPLEMENTATION} · ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}"
    for d in /dev/esp32 /dev/rplidar; do
        if [ -e "$d" ]; then echo -e "  $ok $d"; else echo -e "  $no $d (устройства нет)"; fi
    done
    if lsusb -d 8086: >/dev/null 2>&1; then echo -e "  $ok USB-устройство Intel (RealSense)"; else echo -e "  $no RealSense не найден"; fi
    if [ -f /ws/install/setup.bash ]; then echo -e "  $ok рабочее пространство /ws собрано"; else echo -e "  $no /ws/install нет — выполни cb"; fi
}
jetbot_banner
