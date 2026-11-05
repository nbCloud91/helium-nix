# helium-nix

> **For personal use.** This is my own packaging of the
> [Helium browser](https://github.com/imputnet/helium) for my NixOS machine. It is
> not affiliated with or endorsed by the Helium developers, comes with no support,
> and may change or break without notice. You're welcome to read or copy it, but
> pin a revision and review it before depending on it.

A Nix flake that repackages upstream's **signed** x86_64 Linux release tarball.
Nothing is compiled; the binaries are patched with `autoPatchelfHook` and wrapped.

## Trust model

- Only release artifacts from [`imputnet/helium-linux`](https://github.com/imputnet/helium-linux/releases) are used.
- Before a new version is recorded, its detached signature is verified against the
  Helium signing key committed in [`keys/`](keys/), with primary fingerprint pinned in
  [`update.sh`](update.sh):
  `BE67 7C19 89D3 5EAB 2C5F 26C9 3516 01AD 01D6 378E`
  (as published in the helium-linux README).
- A GitHub Actions workflow checks for releases every 6 hours, verifies, builds, and
  commits the bump to `version.json`. Actions are pinned by commit SHA.

## Usage

```nix
inputs.helium = {
  url = "github:nbCloud91/helium-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};

# then
home.packages = [ inputs.helium.packages.x86_64-linux.helium ];
# or with Widevine (unfree; needs allowUnfree for widevine-cdm):
home.packages = [ (inputs.helium.packages.x86_64-linux.helium.override { withWidevine = true; }) ];
```

An overlay is also exposed as `overlays.default`.

Manual bump: `nix run .#update` from the repo root.

## License

The Nix packaging in this repo is MIT-licensed. Helium itself is GPL-3.0 (see upstream).
