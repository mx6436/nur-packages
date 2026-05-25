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
    ./0002-go-data-dir.patch
    ./0003-credit-shopping-storage.patch
  ];
})
