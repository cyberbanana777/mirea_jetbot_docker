# jetbot_mirea · образ lowlevel (ROS2 Humble на Jetson Nano)

Образ с ROS2 Humble, CycloneDDS 0.10.x и репозиторием `jetbot_mirea`. Запускает драйверы робота (ESP32, лидар, RealSense) и совместим по DDS с ноутбуком на Humble. Хост Jetson остаётся на Ubuntu 20.04.

Что внутри: база `ros:humble-ros-base` (Ubuntu 22.04, arm64), `rmw_cyclonedds_cpp`, `realsense2_camera`, `compressed_image_transport`, `tf2_ros`, `teleop_twist_keyboard`, `xacro`, пакеты робота (`serial_bridge_package`, `sllidar_ros2`, `lidar_filter`, `realsense_pkg`, `completed_scripts_jetbot`, `jetbot_mirea_description`), пользователь без root (группы `video`, `dialout`, `plugdev`, sudo без пароля), сетевые утилиты. Не входят: Gazebo, `realsense_ros_gazebo`, `trajectory_maker`, Tk-GUI настройки ПИД (они нужны на ноутбуке). Nav2 и slam-toolbox включаются параметром `WITH_NAV2=1` в `.env`.

## 1. Подготовка (один раз)

1. Положи репозиторий `jetbot_mirea` в папку `./src` рядом с `Dockerfile` (должно быть `./src/serial_bridge_package`, `./src/sllidar_ros2` и т. д.).
2. На хосте должны быть udev-правила симлинков `/dev/esp32` и `/dev/rplidar` (шаги A2.2 и A3 из README проекта) и правила RealSense (`99-realsense-libusb.rules`), если камера открывается без sudo.
3. Проверь UID пользователя: `id`. Если не 1000, поправь `USER_UID` и `USER_GID` в `.env`.

## 2. Сборка

```bash
./build_image.sh
```

Сборка идёт на самой Nano: по умолчанию `BUILD_JOBS=2` (Nano с 4 ГБ ОЗУ). Если сборка падает по памяти, включи swap и оставь 2 потока или поставь 1. В конце сборки образ сам проверяет, что все пакеты робота, `realsense2_camera` и `rmw_cyclonedds_cpp` на месте. Если проверка не прошла, образ не создаётся.

## 3. Запуск

```bash
docker compose run --rm lowlevel                        # интерактивный shell
docker compose --profile bringup up bringup             # сразу запустить драйверы (шаг R1)
```

Или вручную внутри контейнера: `ros2 launch completed_scripts_jetbot jetbot_sensors_and_motors.launch.py enable_front_camera:=True`.

При входе баннер показывает, видны ли `/dev/esp32`, `/dev/rplidar` и камера.

## 4. Проверки после первой сборки

```bash
# версия CycloneDDS из пакета
docker compose run --rm lowlevel dpkg-query -W 'ros-*-cyclonedds'

# обмен с ноутбуком (на ноутбуке: тот же ROS_DOMAIN_ID и RMW_IMPLEMENTATION=rmw_cyclonedds_cpp)
docker compose run --rm lowlevel ros2 run demo_nodes_cpp talker
# на ноутбуке:  ros2 topic echo /chatter

# CUDA (нужна только для будущего compute-образа)
DOCKER_RUNTIME=nvidia docker compose run --rm lowlevel ls /usr/local/cuda/lib64
```

## 5. Разработка

Раскомментируй в `docker-compose.yml` строку `- ./src:/ws/src`, зайди в контейнер и пересобери: `cb` (алиас на `colcon build`).

## 6. Если что-то не так

- **DDS не видит ноутбук.** Проверь `ROS_DOMAIN_ID` и подсеть; при необходимости задай пиры в `cyclonedds.xml` (пример в комментарии).
- **Нет `/dev/esp32` или `/dev/rplidar`.** Правила udev ставятся на хосте, не в контейнере.
- **RealSense IMU не работает.** Известное ограничение ядра Nano; проверяется на железе (патченое ядро или режим RSUSB).
- **Сборка падает на `realsense2-camera`.** Пришли лог: запасной вариант — сборка librealsense из исходников.
