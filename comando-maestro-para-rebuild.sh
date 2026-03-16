sudo nixos-rebuild switch --flake /home/ravn/Work/hydenix#default

sudo nixos-rebuild switch --flake /home/hydenix/hydenix#default
git clone https://github.com/richen604/hydenix /mnt/etc/nixos
# Instalar
sudo nixos-install --flake /mnt/etc/nixos#default


# Para actualizar el sistema
sudo nixos-rebuild switch --flake /home/hydenix/hydenix#default

# Para actualizar el sistema y el home-manager
sudo nixos-rebuild switch --flake .#default
home-manager switch --flake .#default


nix flake update --commit-lock-file   