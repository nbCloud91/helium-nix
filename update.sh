# Bump version.json to upstream's latest release, but only after its
# signature verifies against the key committed in keys/ (never a fetched one:
# a key served next to the release would vouch for whatever is beside it).
# Run from the repo root: nix run .#update
set -euo pipefail

PRIMARY_FPR=BE677C1989D35EAB2C5F26C9351601AD01D6378E
REPO=imputnet/helium-linux

auth=()
[[ -n "${GH_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GH_TOKEN")

latest=$(curl -fsS "${auth[@]}" "https://api.github.com/repos/$REPO/releases/latest" | jq -er '.tag_name')
current=$(jq -er .version version.json)

if [[ "$latest" == "$current" ]]; then
  echo "helium: up to date at $current"
  exit 0
fi
if [[ "$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -1)" != "$latest" ]]; then
  echo "helium: refusing downgrade $current -> $latest" >&2
  exit 1
fi
echo "helium: $current -> $latest"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tarball="helium-$latest-x86_64_linux.tar.xz"
base="https://github.com/$REPO/releases/download/$latest"
curl -fsSL -o "$work/$tarball" "$base/$tarball"
curl -fsSL -o "$work/$tarball.asc" "$base/$tarball.asc"

export GNUPGHOME="$work/gnupg"
mkdir -m 700 "$GNUPGHOME"
gpg --batch --quiet --import keys/helium-signing-key.asc

# VALIDSIG's last field is the primary key fingerprint, whichever subkey signed.
# GOODSIG is required too: an expired or revoked key yields VALIDSIG with EXPKEYSIG/REVKEYSIG instead.
gpg_rc=0
status=$(gpg --batch --status-fd 1 --verify "$work/$tarball.asc" "$work/$tarball" 2>/dev/null) || gpg_rc=$?
if ((gpg_rc != 0)) ||
  ! grep -q '^\[GNUPG:\] GOODSIG ' <<<"$status" ||
  grep -Eq '^\[GNUPG:\] (EXPKEYSIG|REVKEYSIG|EXPSIG|BADSIG|ERRSIG) ' <<<"$status" ||
  ! grep -Eq "^\[GNUPG:\] VALIDSIG .* $PRIMARY_FPR\$" <<<"$status"; then
  echo "helium: signature verification FAILED for $tarball (gpg rc=$gpg_rc)" >&2
  exit 1
fi
echo "helium: signature OK ($PRIMARY_FPR)"

# The tag isn't signed, but the tarball's top-level dir is: reject an old signed tarball under a new tag.
topdir=$(tar -tJf "$work/$tarball" | sed -n 1p) # not head: SIGPIPE + pipefail would abort
if [[ "$topdir" != "helium-$latest-x86_64_linux/" ]]; then
  echo "helium: tarball contains '$topdir', expected helium-$latest-x86_64_linux/ (replayed release?)" >&2
  exit 1
fi

hash=$(nix hash file --type sha256 --sri "$work/$tarball")
jq -n --arg v "$latest" --arg h "$hash" '{version: $v, hash: $h}' >version.json
echo "helium: version.json -> $latest ($hash)"
