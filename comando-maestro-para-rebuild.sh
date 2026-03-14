sudo nixos-rebuild switch --flake /home/ravn/Work/hydenix#default

sudo nixos-rebuild switch --flake /home/hydenix/hydenix#default
git clone https://github.com/richen604/hydenix /mnt/etc/nixos
# Instalar
sudo nixos-install --flake /mnt/etc/nixos#default