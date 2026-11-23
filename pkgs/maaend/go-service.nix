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

  vendorHash = "sha256-bNh605xWBDPdYoWyblpp8kXTB8kPu2NN127g/6mwGBQ=";

  __structuredAttrs = true;

  modRoot = "agent/go-service";
  subPackages = [ "." ];
})
