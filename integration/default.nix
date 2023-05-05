# WARNING: GENERATED FILE, DO NOT EDIT.
# This file is generated by running hack/bin/generate-local-nix-packages.sh and
# must be regenerated whenever local packages are added or removed, or
# dependencies are added or removed.
{ mkDerivation
, aeson
, aeson-pretty
, array
, async
, base
, bytestring
, bytestring-conversion
, Cabal
, case-insensitive
, containers
, data-default
, directory
, exceptions
, filepath
, gitignoreSource
, http-client
, http-types
, lib
, mtl
, network
, network-uri
, optparse-applicative
, process
, random
, raw-strings-qq
, retry
, scientific
, split
, stm
, string-conversions
, tagged
, text
, time
, transformers
, unliftio
, websockets
, yaml
}:
mkDerivation {
  pname = "integration";
  version = "0.1.0";
  src = gitignoreSource ./.;
  isLibrary = true;
  isExecutable = true;
  setupHaskellDepends = [ base Cabal containers directory filepath ];
  libraryHaskellDepends = [
    aeson
    aeson-pretty
    array
    async
    base
    bytestring
    bytestring-conversion
    case-insensitive
    containers
    data-default
    directory
    exceptions
    filepath
    http-client
    http-types
    mtl
    network
    network-uri
    optparse-applicative
    process
    random
    raw-strings-qq
    retry
    scientific
    split
    stm
    string-conversions
    tagged
    text
    time
    transformers
    unliftio
    websockets
    yaml
  ];
  license = lib.licenses.agpl3Only;
  mainProgram = "integration";
}