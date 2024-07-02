# WARNING: GENERATED FILE, DO NOT EDIT.
# This file is generated by running hack/bin/generate-local-nix-packages.sh and
# must be regenerated whenever local packages are added or removed, or
# dependencies are added or removed.
{ mkDerivation
, aeson
, base
, brig
, bytestring
, cassandra-util
, conduit
, extended
, extra
, gitignoreSource
, imports
, lib
, optparse-applicative
, text
, tinylog
, types-common
, unliftio
, wire-api
, wire-subsystems
}:
mkDerivation {
  pname = "inconsistencies";
  version = "1.0.0";
  src = gitignoreSource ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    aeson
    base
    brig
    bytestring
    cassandra-util
    conduit
    extended
    extra
    imports
    optparse-applicative
    text
    tinylog
    types-common
    unliftio
    wire-api
    wire-subsystems
  ];
  description = "Find handles which belong to deleted users";
  license = lib.licenses.agpl3Only;
  mainProgram = "inconsistencies";
}
