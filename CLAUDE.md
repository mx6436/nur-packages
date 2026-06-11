# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository shape

- This is a NUR/Nix package repository. `flake.nix` exposes packages, the overlay, NixOS modules, and the repo formatter; `default.nix` auto-discovers `pkgs/*/package.nix`; `ci.nix` defines the CI build/cache outputs.
- Package definitions live under `pkgs/*/package.nix`. NixOS modules live under `nixos-modules/` and are auto-imported from `nixos-modules/default.nix`.
- `overlay.nix` is the nixpkgs overlay entry point; keep it in sync with package exports.

## Commands

- Format Nix code with `nix fmt`.
- Use the existing CI path as the main verification gate: CI evaluates packages and builds `nix-build-uncached ci.nix -A cacheOutputs`.
- For local CI-style checks, prefer evaluating/building the same `ci.nix -A cacheOutputs` path rather than inventing a separate test command.

## Package updates

- When a package provides `passthru.updateScript` or an `update.fish`, prefer that updater over manually editing versions and hashes.
- The updater fish scripts use networked tools such as `curl`, `jq`, `nix-prefetch-git`, and `nix-prefetch-url`; account for those dependencies when running them.

## CI and packaging gotchas

- `ci.nix` filters cache/build outputs by package metadata such as `meta.broken`, free licenses, and `preferLocalBuild`; unfree packages such as `natfrp-service` are intentionally excluded from CI cache outputs.
- Do not assume every package targets every platform. Respect each derivation's declared `meta.platforms`.
- `result`, `result-*`, `.maa/`, `.sisyphus`, and `docs/superpowers` are ignored/generated artifacts and should not be committed.
