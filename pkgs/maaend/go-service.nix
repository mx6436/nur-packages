{
  pname,
  version,
  src,
  meta,
  vendorHash,

  buildGoModule,
}:

buildGoModule (finalAttrs: {
  inherit
    version
    src
    meta
    vendorHash
    ;

  pname = "${pname}-go-service";

  modRoot = "agent/go-service";
  subPackages = [ "." ];

  patches = [
    ./go-service-path.patch
  ];
})
