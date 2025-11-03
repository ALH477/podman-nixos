{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.deploy.url = "github:serokell/deploy-rs";
  outputs = inputs@{
    self, nixpkgs, flake-parts, deploy,
  }: flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" ];
    flake.nixosModules.default = import ./module.nix;
    perSystem = { inputs', pkgs, ... }: {
      packages.default = self.nixosConfigurations.example.config.podman-nixos.image;
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [];
        nativeBuildInputs = with pkgs; [
          inputs'.deploy.packages.default
        ];
      };
    };

    flake.nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.default
        {
          system.stateVersion = "25.05";
          users.users.root.password = "nixos";
          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "yes";
          };
        }
      ];
    };
    flake.deploy.nodes.example = {
      sshUser = "root";
      hostname = "127.0.0.1";
      sshOpts = [ "-p" "2222" ];
      profiles.system.path = deploy.lib.x86_64-linux.activate.nixos
        self.nixosConfigurations.example;
    };
  };
}
