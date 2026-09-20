{
  pname,
  version,
  src,
  meta,
  vendorHash,

  buildGoModule,
}:

buildGoModule (finalAttrs: {
  pname = "${pname}-go-service";
  inherit
    version
    src
    meta
    vendorHash
    ;

  __structuredAttrs = true;

  modRoot = "agent/go-service";
  subPackages = [ "." ];

  patches = [
    ./0001-go-data-dir.patch
  ];
})
