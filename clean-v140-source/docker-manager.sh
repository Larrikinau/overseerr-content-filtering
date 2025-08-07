#!/bin/bash

start_docker() {
    echo "Starting Colima (Docker runtime)..."
    colima start
    echo "Docker is ready!"
}

stop_docker() {
    echo "Stopping Colima (Docker runtime)..."
    colima stop
    echo "Docker stopped."
}

case "$1" in
    start)
        start_docker
        ;;
    stop)
        stop_docker
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac
