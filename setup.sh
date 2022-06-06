#!/bin/sh

set -e

apt-get install git ansible
ansible-pull -U https://github.com/alencar-felipe/ansible