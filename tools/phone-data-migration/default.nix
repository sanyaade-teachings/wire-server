# WARNING: GENERATED FILE, DO NOT EDIT.
# This file is generated by running hack/bin/generate-local-nix-packages.sh and
# must be regenerated whenever local packages are added or removed, or
# dependencies are added or removed.
{ mkDerivation
, attoparsec
, base
, cassandra-util
, conduit
, exceptions
, gitignoreSource
, imports
, lens
, lib
, optparse-applicative
, text
, tinylog
}:
mkDerivation {
  pname = "phone-data-migration";
  version = "1.0.0";
  src = gitignoreSource ./.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    attoparsec
    cassandra-util
    conduit
    exceptions
    imports
    lens
    optparse-applicative
    text
    tinylog
  ];
  executableHaskellDepends = [ base ];
  description = "remove phone data from wire-server";
  license = lib.licenses.agpl3Only;
  mainProgram = "phone-data-migration";
}
