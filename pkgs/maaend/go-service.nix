{
  pname,
  version,
  src,
  meta,

  buildGoModule,
}:

buildGoModule (finalAttrs: {
  pname = "${pname}-go-service";
  inherit
    version
    src
    meta
    ;

  vendorHash = "sha256-PPHmkGxGUNwZTqnb8DQLMRBmxs/CCknaspnhqiKkyo4=";

  __structuredAttrs = true;

  modRoot = "agent/go-service";
  subPackages = [ "." ];

  patches = [
    ./0001-go-data-dir.patch
  ];
})
