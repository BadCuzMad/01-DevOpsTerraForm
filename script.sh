#!/bin/bash
sudo apt-get update -y
sudo apt install docker.io -y
sudo groupadd docker
sudo usermod -aG docker ubuntu
