# WARNING: GENERATED FILE, DO NOT EDIT.
# This file is generated by running hack/bin/generate-local-nix-packages.sh and
# must be regenerated whenever local packages are added or removed, or
# dependencies are added or removed.
{ mkDerivation
, aeson
, async
, base
, bilge
, binary
, bytestring
, bytestring-conversion
, containers
, crypton
, crypton-connection
, crypton-x509
, crypton-x509-validation
, data-default
, dns
, dns-util
, exceptions
, extended
, filepath
, gitignoreSource
, hinotify
, HsOpenSSL
, hspec
, hspec-core
, hspec-junit-formatter
, http-client
, http-client-tls
, http-media
, http-types
, http2
, http2-manager
, imports
, interpolate
, kan-extensions
, lens
, lib
, metrics-core
, metrics-wai
, mtl
, optparse-applicative
, pem
, polysemy
, polysemy-wire-zoo
, prometheus-client
, QuickCheck
, random
, servant
, servant-client
, servant-client-core
, servant-server
, tasty
, tasty-hunit
, tasty-quickcheck
, temporary
, text
, tinylog
, transformers
, types-common
, unix
, uuid
, wai
, wai-extra
, wai-utilities
, warp
, warp-tls
, wire-api
, wire-api-federation
, yaml
}:
mkDerivation {
  pname = "federator";
  version = "1.0.0";
  src = gitignoreSource ./.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    aeson
    async
    base
    bilge
    binary
    bytestring
    bytestring-conversion
    containers
    crypton-x509
    crypton-x509-validation
    data-default
    dns
    dns-util
    exceptions
    extended
    filepath
    hinotify
    HsOpenSSL
    http-client
    http-media
    http-types
    http2
    http2-manager
    imports
    kan-extensions
    lens
    metrics-core
    metrics-wai
    mtl
    pem
    polysemy
    polysemy-wire-zoo
    prometheus-client
    servant
    servant-client
    servant-client-core
    servant-server
    text
    tinylog
    transformers
    types-common
    unix
    uuid
    wai
    wai-utilities
    warp
    wire-api
    wire-api-federation
  ];
  executableHaskellDepends = [
    aeson
    async
    base
    bilge
    binary
    bytestring
    bytestring-conversion
    crypton
    crypton-connection
    dns-util
    exceptions
    HsOpenSSL
    hspec
    hspec-core
    hspec-junit-formatter
    http-client-tls
    http-types
    http2-manager
    imports
    kan-extensions
    lens
    optparse-applicative
    polysemy
    QuickCheck
    random
    servant-client-core
    tasty-hunit
    text
    types-common
    uuid
    wire-api
    wire-api-federation
    yaml
  ];
  testHaskellDepends = [
    aeson
    base
    bytestring
    bytestring-conversion
    containers
    crypton-x509-validation
    data-default
    dns-util
    filepath
    HsOpenSSL
    http-media
    http-types
    http2
    http2-manager
    imports
    interpolate
    kan-extensions
    mtl
    polysemy
    polysemy-wire-zoo
    QuickCheck
    servant
    servant-client
    servant-client-core
    servant-server
    tasty
    tasty-hunit
    tasty-quickcheck
    temporary
    text
    tinylog
    transformers
    types-common
    unix
    wai
    wai-extra
    wai-utilities
    warp
    warp-tls
    wire-api
    wire-api-federation
    yaml
  ];
  description = "Federation Service";
  license = lib.licenses.agpl3Only;
}
