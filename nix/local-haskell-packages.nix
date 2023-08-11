# WARNING: GENERATED FILE, DO NOT EDIT.
# This file is generated by running hack/bin/generate-local-nix-packages.sh and
# must be regenerated whenever local packages are added or removed, or
# dependencies are added or removed.
{ gitignoreSource }: hsuper: hself: {
  integration = hself.callPackage ../integration/default.nix { inherit gitignoreSource; };
  bilge = hself.callPackage ../libs/bilge/default.nix { inherit gitignoreSource; };
  brig-types = hself.callPackage ../libs/brig-types/default.nix { inherit gitignoreSource; };
  cargohold-types = hself.callPackage ../libs/cargohold-types/default.nix { inherit gitignoreSource; };
  cassandra-util = hself.callPackage ../libs/cassandra-util/default.nix { inherit gitignoreSource; };
  deriving-swagger2 = hself.callPackage ../libs/deriving-swagger2/default.nix { inherit gitignoreSource; };
  dns-util = hself.callPackage ../libs/dns-util/default.nix { inherit gitignoreSource; };
  extended = hself.callPackage ../libs/extended/default.nix { inherit gitignoreSource; };
  galley-types = hself.callPackage ../libs/galley-types/default.nix { inherit gitignoreSource; };
  gundeck-types = hself.callPackage ../libs/gundeck-types/default.nix { inherit gitignoreSource; };
  hscim = hself.callPackage ../libs/hscim/default.nix { inherit gitignoreSource; };
  http2-manager = hself.callPackage ../libs/http2-manager/default.nix { inherit gitignoreSource; };
  imports = hself.callPackage ../libs/imports/default.nix { inherit gitignoreSource; };
  jwt-tools = hself.callPackage ../libs/jwt-tools/default.nix { inherit gitignoreSource; };
  metrics-core = hself.callPackage ../libs/metrics-core/default.nix { inherit gitignoreSource; };
  metrics-wai = hself.callPackage ../libs/metrics-wai/default.nix { inherit gitignoreSource; };
  polysemy-wire-zoo = hself.callPackage ../libs/polysemy-wire-zoo/default.nix { inherit gitignoreSource; };
  ropes = hself.callPackage ../libs/ropes/default.nix { inherit gitignoreSource; };
  schema-profunctor = hself.callPackage ../libs/schema-profunctor/default.nix { inherit gitignoreSource; };
  sodium-crypto-sign = hself.callPackage ../libs/sodium-crypto-sign/default.nix { inherit gitignoreSource; };
  ssl-util = hself.callPackage ../libs/ssl-util/default.nix { inherit gitignoreSource; };
  tasty-cannon = hself.callPackage ../libs/tasty-cannon/default.nix { inherit gitignoreSource; };
  types-common-aws = hself.callPackage ../libs/types-common-aws/default.nix { inherit gitignoreSource; };
  types-common-journal = hself.callPackage ../libs/types-common-journal/default.nix { inherit gitignoreSource; };
  types-common = hself.callPackage ../libs/types-common/default.nix { inherit gitignoreSource; };
  wai-utilities = hself.callPackage ../libs/wai-utilities/default.nix { inherit gitignoreSource; };
  wire-api-federation = hself.callPackage ../libs/wire-api-federation/default.nix { inherit gitignoreSource; };
  wire-api = hself.callPackage ../libs/wire-api/default.nix { inherit gitignoreSource; };
  wire-message-proto-lens = hself.callPackage ../libs/wire-message-proto-lens/default.nix { inherit gitignoreSource; };
  zauth = hself.callPackage ../libs/zauth/default.nix { inherit gitignoreSource; };
  background-worker = hself.callPackage ../services/background-worker/default.nix { inherit gitignoreSource; };
  brig = hself.callPackage ../services/brig/default.nix { inherit gitignoreSource; };
  cannon = hself.callPackage ../services/cannon/default.nix { inherit gitignoreSource; };
  cargohold = hself.callPackage ../services/cargohold/default.nix { inherit gitignoreSource; };
  federator = hself.callPackage ../services/federator/default.nix { inherit gitignoreSource; };
  galley = hself.callPackage ../services/galley/default.nix { inherit gitignoreSource; };
  gundeck = hself.callPackage ../services/gundeck/default.nix { inherit gitignoreSource; };
  proxy = hself.callPackage ../services/proxy/default.nix { inherit gitignoreSource; };
  spar = hself.callPackage ../services/spar/default.nix { inherit gitignoreSource; };
  assets = hself.callPackage ../tools/db/assets/default.nix { inherit gitignoreSource; };
  auto-whitelist = hself.callPackage ../tools/db/auto-whitelist/default.nix { inherit gitignoreSource; };
  billing-team-member-backfill = hself.callPackage ../tools/db/billing-team-member-backfill/default.nix { inherit gitignoreSource; };
  find-undead = hself.callPackage ../tools/db/find-undead/default.nix { inherit gitignoreSource; };
  inconsistencies = hself.callPackage ../tools/db/inconsistencies/default.nix { inherit gitignoreSource; };
  migrate-sso-feature-flag = hself.callPackage ../tools/db/migrate-sso-feature-flag/default.nix { inherit gitignoreSource; };
  move-team = hself.callPackage ../tools/db/move-team/default.nix { inherit gitignoreSource; };
  repair-handles = hself.callPackage ../tools/db/repair-handles/default.nix { inherit gitignoreSource; };
  service-backfill = hself.callPackage ../tools/db/service-backfill/default.nix { inherit gitignoreSource; };
  fedcalls = hself.callPackage ../tools/fedcalls/default.nix { inherit gitignoreSource; };
  rex = hself.callPackage ../tools/rex/default.nix { inherit gitignoreSource; };
  stern = hself.callPackage ../tools/stern/default.nix { inherit gitignoreSource; };
}
