#!/usr/bin/env bash
# Сборка образа lowlevel. Репозиторий должен лежать в ./src
set -euo pipefail
cd "$(dirname "$0")"

git -C src pull || echo "Предупреждение: git pull не удался, собираю из текущего ./src" >&2

if [ ! -d src/serial_bridge_package ]; then
    echo "Не найден ./src/serial_bridge_package — положи репозиторий jetbot_mirea в папку ./src рядом с Dockerfile." >&2
    exit 1
fi

# Подставляем UID/GID текущего пользователя, если они не заданы вручную
export USER_UID="${USER_UID:-$(id -u)}"
export USER_GID="${USER_GID:-$(id -g)}"

docker compose build lowlevel
echo "Готово: образ jetbot-lowlevel:humble"
