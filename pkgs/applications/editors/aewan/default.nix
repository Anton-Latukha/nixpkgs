{ lib, stdenv, fetchurl, zlib, ncurses }:

stdenv.mkDerivation rec {
  pname = "aewan";
  version = "1.0.01";

  src = fetchurl {
    url = "mirror://sourceforge/aewan/${pname}-${version}.tar.gz";
    sha256 = "5266dec5e185e530b792522821c97dfa5f9e3892d0dca5e881d0c30ceac21817";
  };

  buildInputs = [ zlib ncurses ];

  meta = {
    description = "Ascii-art Editor Without A Name";
    homepage = "http://aewan.sourceforge.net/";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.unix;
  };
}
