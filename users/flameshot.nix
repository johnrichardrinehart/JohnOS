{ mkDerivation, lib, fetchFromGitHub, qtbase, cmake, qttools, qtsvg }:

mkDerivation rec {
  pname = "flameshot";
  version = "veracioux-lost_focus_workaround";

  src = fetchFromGitHub {
    owner = "flameshot-org";
    repo = "flameshot";
    rev = "dabc596566c60378f313d26f2fe143d2a37ede5b";
    sha256 = "/6mYjM5kDazPZ+KvCunAhXK7mWEJRvn13Xx/JzhBHJg=";
  };

  nativeBuildInputs = [ cmake qttools qtsvg ];
  buildInputs = [ qtbase ];

  meta = with lib; {
    description = "Powerful yet simple to use screenshot software";
    homepage = "https://github.com/flameshot-org/flameshot";
    maintainers = with maintainers; [ scode ];
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
