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

  vendorHash = "sha256-Vu0VU+6/qzifu9dW3A2wbBwJL9jvUap0dN3YcoKVl5I=";

  __structuredAttrs = true;

  modRoot = "agent/go-service";
  subPackages = [ "." ];
})
