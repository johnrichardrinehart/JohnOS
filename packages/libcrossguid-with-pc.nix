{
  libcrossguid,
  lib,
}:

libcrossguid.overrideAttrs (old: {
  pname = "libcrossguid-with-pc";

  installPhase = (old.installPhase or "") + ''
    mkdir -p "$out/lib/pkgconfig"
    cat > "$out/lib/pkgconfig/crossguid.pc" <<EOF
    prefix=$out
    exec_prefix=\''${prefix}
    libdir=\''${prefix}/lib
    includedir=\''${prefix}/include

    Name: crossguid
    Description: Cross platform GUID library
    Version: ${old.version or "2016-02-21"}
    Libs: -L\''${libdir} -lcrossguid
    Cflags: -I\''${includedir}
    EOF
    cp "$out/lib/pkgconfig/crossguid.pc" "$out/lib/pkgconfig/crossguid2.pc"
  '';

  meta = (old.meta or { }) // {
    description = ((old.meta.description or "Cross platform GUID library")
      + " with pkg-config metadata");
  };
})
