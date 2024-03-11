# WARNING: GENERATED FILE, DO NOT EDIT.
# This file is generated by running hack/bin/generate-local-nix-packages.sh and
# must be regenerated whenever local packages are added or removed, or
# dependencies are added or removed.
{ mkDerivation
, aeson
, aeson-pretty
, amazonka
, amazonka-core
, amazonka-sns
, amazonka-sqs
, async
, attoparsec
, auto-update
, base
, base16-bytestring
, bilge
, bytestring
, bytestring-conversion
, cassandra-util
, containers
, criterion
, errors
, exceptions
, extended
, extra
, foldl
, gitignoreSource
, gundeck-types
, hedis
, HsOpenSSL
, http-client
, http-client-tls
, http-types
, imports
, kan-extensions
, lens
, lens-aeson
, lib
, metrics-core
, metrics-wai
, MonadRandom
, mtl
, multiset
, network
, network-uri
, optparse-applicative
, psqueues
, QuickCheck
, quickcheck-instances
, quickcheck-state-machine
, random
, raw-strings-qq
, resourcet
, retry
, safe
, safe-exceptions
, scientific
, servant-server
, tagged
, tasty
, tasty-ant-xml
, tasty-hunit
, tasty-quickcheck
, text
, time
, tinylog
, tls
, types-common
, types-common-aws
, unliftio
, unordered-containers
, uuid
, wai
, wai-extra
, wai-middleware-gunzip
, wai-predicates
, wai-routing
, wai-utilities
, websockets
, wire-api
, yaml
}:
mkDerivation {
  pname = "gundeck";
  version = "1.45.0";
  src = gitignoreSource ./.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    aeson
    amazonka
    amazonka-core
    amazonka-sns
    amazonka-sqs
    async
    attoparsec
    auto-update
    base
    bilge
    bytestring
    bytestring-conversion
    cassandra-util
    containers
    errors
    exceptions
    extended
    extra
    foldl
    gundeck-types
    hedis
    http-client
    http-client-tls
    http-types
    imports
    lens
    lens-aeson
    metrics-core
    metrics-wai
    mtl
    network-uri
    psqueues
    raw-strings-qq
    resourcet
    retry
    safe-exceptions
    servant-server
    text
    time
    tinylog
    tls
    types-common
    types-common-aws
    unliftio
    unordered-containers
    uuid
    wai
    wai-extra
    wai-middleware-gunzip
    wai-predicates
    wai-routing
    wai-utilities
    wire-api
    yaml
  ];
  executableHaskellDepends = [
    aeson
    async
    base
    base16-bytestring
    bilge
    bytestring
    bytestring-conversion
    cassandra-util
    containers
    exceptions
    gundeck-types
    HsOpenSSL
    http-client
    http-client-tls
    imports
    kan-extensions
    lens
    lens-aeson
    metrics-wai
    network
    network-uri
    optparse-applicative
    random
    retry
    safe
    tagged
    tasty
    tasty-ant-xml
    tasty-hunit
    text
    tinylog
    types-common
    uuid
    wai-utilities
    websockets
    wire-api
    yaml
  ];
  testHaskellDepends = [
    aeson
    aeson-pretty
    amazonka
    amazonka-core
    async
    base
    bytestring-conversion
    containers
    exceptions
    gundeck-types
    HsOpenSSL
    imports
    lens
    metrics-wai
    MonadRandom
    mtl
    multiset
    network-uri
    QuickCheck
    quickcheck-instances
    quickcheck-state-machine
    scientific
    tasty
    tasty-hunit
    tasty-quickcheck
    text
    time
    tinylog
    types-common
    wai-utilities
    wire-api
  ];
  benchmarkHaskellDepends = [
    amazonka
    base
    criterion
    gundeck-types
    HsOpenSSL
    imports
    lens
    random
    text
    types-common
    uuid
  ];
  description = "Push Notification Hub";
  license = lib.licenses.agpl3Only;
}
