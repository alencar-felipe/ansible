# ansible

## Instructions

### 1. Partitioning

```
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart primary 512MiB -8GiB
parted /dev/sda -- mkpart primary linux-swap -8GiB 100%
parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
parted /dev/sda -- set 3 esp on
```
