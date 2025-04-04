#!/usr/bin/env bash

set -eou pipefail

# syn-protobuf.sh is a bash script to sync the protobuf
# files using ibc-proto-compiler. This script will checkout
# the protobuf files from the git versions specified in
# proto/src/prost/COSMOS_SDK_COMMIT and
# proto/src/prost/IBC_GO_COMMIT. If you want to sync
# the protobuf files to a newer version, modify the
# corresponding of those 2 files by specifying the commit ID
# that you wish to checkout from.

# This script should be run from the root directory of ibc-proto-rs.

# We can specify where to clone the git repositories
# for cosmos-sdk and ibc-go. By default they are cloned
# to /tmp/cosmos-sdk.git and /tmp/ibc-go.git.
# We can override this to existing directories
# that already have a clone of the repositories,
# so that there is no need to clone the entire
# repositories over and over again every time
# the script is called.

CACHE_PATH="${XDG_CACHE_HOME:-$HOME/.cache}"/ibc-proto-rs-build
COSMOS_SDK_GIT="${COSMOS_SDK_GIT:-$CACHE_PATH/cosmos-sdk.git}"
IBC_GO_GIT="${IBC_GO_GIT:-$CACHE_PATH/ibc-go.git}"
COSMOS_ICS_GIT="${COSMOS_ICS_GIT:-$CACHE_PATH/interchain-security.git}"
NFT_TRANSFER_GIT="${NFT_TRANSFER_GIT:-$CACHE_PATH/nft-transfer.git}"
ETHERMINT_GIT="${ETHERMINT_GIT:-$CACHE_PATH/crypto-org-chain/ethermint.git}"

COSMOS_SDK_COMMIT="$(cat src/COSMOS_SDK_COMMIT)"
IBC_GO_COMMIT="$(cat src/IBC_GO_COMMIT)"
INTERCHAIN_SECURITY_COMMIT="$(cat src/INTERCHAIN_SECURITY_COMMIT)"
NFT_TRANSFER_COMMIT="$(cat src/NFT_TRANSFER_COMMIT)"
ETHERMINT_COMMIT="$(cat src/ETHERMINT_COMMIT)"

echo "COSMOS_SDK_COMMIT: $COSMOS_SDK_COMMIT"
echo "IBC_GO_COMMIT: $IBC_GO_COMMIT"
echo "INTERCHAIN_SECURITY_COMMIT: $INTERCHAIN_SECURITY_COMMIT"
echo "NFT_TRANSFER_COMMIT: $NFT_TRANSFER_COMMIT"
echo "ETHERMINT_COMMIT: $ETHERMINT_COMMIT"

# Use either --ics-commit flag for commit ID,
# or --ics-tag for git tag. Because we can't modify
# proto-compiler to have smart detection on that.

if [[ "$INTERCHAIN_SECURITY_COMMIT" =~ ^[a-zA-Z0-9]{40}$ ]]
then
    ICS_COMMIT_OPTION="--ics-commit"
else
    ICS_COMMIT_OPTION="--ics-tag"
fi

# If the git directories does not exist, clone them as
# bare git repositories so that no local modification
# can be done there.

if [[ ! -e "$COSMOS_ICS_GIT" ]]
then
    echo "Cloning interchain-security source code to as bare git repository to $COSMOS_ICS_GIT"
    git clone --mirror https://github.com/cosmos/interchain-security.git "$COSMOS_ICS_GIT"
else
    echo "Using existing interchain-security bare git repository at $COSMOS_ICS_GIT"
fi

# Use either --sdk-commit flag for commit ID,
# or --sdk-tag for git tag. Because we can't modify
# proto-compiler to have smart detection on that.

if [[ "$COSMOS_SDK_COMMIT" =~ ^[a-zA-Z0-9]{40}$ ]]
then
    SDK_COMMIT_OPTION="--sdk-commit"
else
    SDK_COMMIT_OPTION="--sdk-tag"
fi

# If the git directories does not exist, clone them as
# bare git repositories so that no local modification
# can be done there.

if [[ ! -e "$COSMOS_SDK_GIT" ]]
then
    echo "Cloning cosmos-sdk source code to as bare git repository to $COSMOS_SDK_GIT"
    git clone --mirror https://github.com/cosmos/cosmos-sdk.git "$COSMOS_SDK_GIT"
else
    echo "Using existing cosmos-sdk bare git repository at $COSMOS_SDK_GIT"
fi

if [[ ! -e "$IBC_GO_GIT" ]]
then
    echo "Cloning ibc-go source code to as bare git repository to $IBC_GO_GIT"
    git clone --mirror https://github.com/cosmos/ibc-go.git "$IBC_GO_GIT"
else
    echo "Using existing ibc-go bare git repository at $IBC_GO_GIT"
fi

if [[ ! -e "$NFT_TRANSFER_GIT" ]]
then
    echo "Cloning nft-transfer source code to as bare git repository to $NFT_TRANSFER_GIT"
    git clone --mirror https://github.com/bianjieai/nft-transfer.git "$NFT_TRANSFER_GIT"
else
    echo "Using existing nft-transfer bare git repository at $NFT_TRANSFER_GIT"
fi


if [[ ! -e "$ETHERMINT_GIT" ]]
then
    echo "Cloning ethermint source code to as bare git repository to $ETHERMINT_GIT"
    git clone --mirror https://github.com/crypto-org-chain/ethermint "$ETHERMINT_GIT"
else
    echo "Using existing ethermint bare git repository at $ETHERMINT_GIT"
fi

# Update the repositories using git fetch. This is so that
# we keep local copies of the repositories up to sync first.
pushd "$COSMOS_ICS_GIT"
git fetch
popd

pushd "$COSMOS_SDK_GIT"
git fetch
popd

pushd "$IBC_GO_GIT"
git fetch
popd

pushd "$NFT_TRANSFER_GIT"
git fetch
popd

pushd "$ETHERMINT_GIT"
git fetch
popd

# Create a new temporary directory to check out the
# actual source files from the bare git repositories.
# This is so that we do not accidentally use an unclean
# local copy of the source files to generate the protobuf.
COSMOS_ICS_DIR=$(mktemp -d /tmp/interchain-security-XXXXXXXX)

pushd "$COSMOS_ICS_DIR"
git clone "$COSMOS_ICS_GIT" .
git checkout "$INTERCHAIN_SECURITY_COMMIT"

cd proto
buf mod prune
buf mod update
buf export -v -o ../proto-include
popd

COSMOS_SDK_DIR=$(mktemp -d /tmp/cosmos-sdk-XXXXXXXX)

pushd "$COSMOS_SDK_DIR"
git clone "$COSMOS_SDK_GIT" .
git checkout "$COSMOS_SDK_COMMIT"

cd proto
buf mod prune
buf mod update
buf export -v -o ../proto-include
popd

cat << "EOF" >> "$COSMOS_SDK_DIR/proto-include/cosmos/staking/v1beta1/staking.proto"

// InfractionType indicates the infraction type a validator commited.
enum InfractionType {
  option (gogoproto.goproto_enum_prefix) = false;

  // UNSPECIFIED defines an empty infraction type.
  INFRACTION_TYPE_UNSPECIFIED = 0 [(gogoproto.enumvalue_customname) = "InfractionEmpty"];
  // DOUBLE_SIGN defines a validator that double-signs a block.
  INFRACTION_TYPE_DOUBLE_SIGN = 1 [(gogoproto.enumvalue_customname) = "DoubleSign"];
  // DOWNTIME defines a validator that missed signing too many blocks.
  INFRACTION_TYPE_DOWNTIME = 2 [(gogoproto.enumvalue_customname) = "Downtime"];
}
EOF

IBC_GO_DIR=$(mktemp -d /tmp/ibc-go-XXXXXXXX)

pushd "$IBC_GO_DIR"
git clone "$IBC_GO_GIT" .
git checkout "$IBC_GO_COMMIT"

cd proto
buf export -v -o ../proto-include
popd

NFT_TRANSFER_DIR=$(mktemp -d /tmp/nft-transfer-XXXXXXXX)

pushd "$NFT_TRANSFER_DIR"
git clone "$NFT_TRANSFER_GIT" .
git checkout "$NFT_TRANSFER_COMMIT"

cd proto
buf export -v -o ../proto-include
rm ../proto-include/ibc/core/client/v1/client.proto
popd

ETHERMINT_DIR=$(mktemp -d /tmp/ethermint-XXXXXXXX)

pushd "$ETHERMINT_DIR"
git clone "$ETHERMINT_GIT" .
git switch -c "$ETHERMINT_COMMIT"

cd proto
buf export -v -o ../proto-include
popd

# Remove the existing generated protobuf files
# so that the newly generated code does not
# contain removed files.

rm -rf src/prost
mkdir -p src/prost

cd tools/proto-compiler

cargo build

# Run the proto-compiler twice,
# once for std version with --build-tonic set to true
# and once for no-std version with --build-tonic set to false

cargo run -- compile \
  --ics "$COSMOS_ICS_DIR/proto-include" \
  --sdk "$COSMOS_SDK_DIR/proto-include" \
  --ibc "$IBC_GO_DIR/proto-include" \
  --nft "$NFT_TRANSFER_DIR/proto-include" \
  --ethermint "$ETHERMINT_DIR/proto-include" \
  --out ../../src/prost

cd ../..

# Remove generated ICS23 code because it is not used,
# we instead re-exports the `ics23` crate type definitions.
rm -f src/prost/cosmos.ics23.v1.rs

# Remove `cosmos.base.store` module as it does not compile
# out of the box and we do not have a use for it at the moment.
rm -f src/prost/cosmos.base.store.v1beta1.rs

# The Tendermint ABCI protos are unused from within ibc-proto
rm -f src/prost/tendermint.abci.rs

# Remove the temporary checkouts of the repositories
rm -rf "$COSMOS_ICS_DIR"
rm -rf "$COSMOS_SDK_DIR"
rm -rf "$IBC_GO_DIR"
rm -rf "$NFT_TRANSFER_DIR"
rm -rf "$ETHERMINT_DIR"
