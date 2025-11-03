# podman-nixos

Run nixos in podman. There is an option `--systemd` of `podman run` to run systemd inside the container. We can use this to run a nixos with systemd.

# usage

```bash
podman run -it -p 2222:22 docker.io/anillc/nixos
```

Then you can ssh into the container with password `nixos`:

```bash
ssh root@127.0.0.1 -p 2222
```

You can use tools like `deploy-rs` to deploy configurations to the container. Example configuration:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.deploy.url = "github:serokell/deploy-rs";
  inputs.podman-nixos.url = "github:Anillc/podman-nixos";
  outputs = inputs@{
    self, nixpkgs, flake-parts, deploy, podman-nixos,
  }: flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" ];
    perSystem = { inputs', pkgs, ... }: {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [];
        nativeBuildInputs = with pkgs; [
          inputs'.deploy.packages.default
        ];
      };
    };
    flake.nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        podman-nixos.nixosModules.default
        {
          system.stateVersion = "25.05";
          users.users.root.openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJqu43h92/UcQLf+E7AnUqmjjdGLkcazB9Z9nNRferqD"
          ];
          services.openssh.enable = true;
        }
      ];
    };
    flake.deploy.nodes.nixos = {
      sshUser = "root";
      hostname = "127.0.0.1";
      sshOpts = [ "-p" "2222" ];
      profiles.system.path = deploy.lib.x86_64-linux.activate.nixos
        self.nixosConfigurations.nixos;
    };
  };
}
```

Then use `deploy -s .#nixos` to deploy the configuration to the container.
