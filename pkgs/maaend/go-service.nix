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

  vendorHash = "sha256-0xZ9CVPVp1szC+7x95R1Ua3Bvt6N6x/mewAsdAJuM3A=";

  __structuredAttrs = true;

  modRoot = "agent/go-service";
  subPackages = [ "." ];

  patches = [
    ./0001-go-data-dir.patch
  ];
})
