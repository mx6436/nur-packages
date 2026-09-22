{ lib, libei, fetchFromGitLab }:

# MaaFramework's Linux controller requires libei >= 1.6.0, while
# nixos-26.05 still provides 1.5.0. Keep newer nixpkgs versions unchanged.
if lib.versionAtLeast libei.version "1.6.0" then
  libei
else
  libei.overrideAttrs {
    version = "1.6.0";
    src = fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "libinput";
      repo = "libei";
      rev = "1.6.0";
      hash = "sha256-fUeMdRK7uoRvgvY3INMorwnTleLrLA5xOeYBFp1qXeI=";
    };
  }
