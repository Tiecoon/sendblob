{
  pkgs,
  webRoot,
}:

# Build the frontend first with npm run build:release. Only its output and a
# statically linked HTTP server enter the image, not the build toolchains.
pkgs.dockerTools.buildLayeredImage {
  name = "sendblob";
  tag = "latest";
  contents = pkgs.runCommand "sendblob-root" { } ''
    test -f ${webRoot}/index.html
    mkdir -p $out/bin $out/www $out/share/licenses/darkhttpd
    cp ${pkgs.lib.getExe pkgs.pkgsStatic.darkhttpd} $out/bin/darkhttpd
    cp ${pkgs.pkgsStatic.darkhttpd}/share/doc/darkhttpd/LICENSE $out/share/licenses/darkhttpd/
    cp -r ${webRoot}/. $out/www/
  '';
  config = {
    User = "65534:65534";
    Entrypoint = [
      "/bin/darkhttpd"
      "/www"
      "--port"
      "8080"
      "--maxconn"
      "128"
      "--timeout"
      "15"
      "--no-listing"
      "--hide-dotfiles"
      "--no-server-id"
      "--header"
      "X-Content-Type-Options: nosniff"
      "--header"
      "Cache-Control: no-cache"
    ];
    ExposedPorts."8080/tcp" = { };
  };
}
