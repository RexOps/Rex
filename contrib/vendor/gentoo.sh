# This script patches the tree, and dist.ini to remove plugins
# and soforth that are either useless, or harmful, when building
# rex from git sources for Gentoo
#
# Many of these are useful for authorship to ensure the code meets
# various standards, but this is not useful at a point of consumption
# as defects in things like documentation or spelling, aren't things
# that should be considered "blockers" for an end user, and can
# substantially inflate the dependency tree without adding any user
# value

# usage:
#   cd ${git_root}
#   bash contrib/vendor/gentoo.sh

info() {
  printf "contrib/vendor/gentoo.sh: %s\n" "$@" >&1
}
err() {
  printf "contrib/vendor/gentoo.sh: ERROR: %s\n" "$@" >&1
  exit 1
}

blacklist=(
  PodSyntaxTests
  Test::MinimumVersion
  Test::Perl::Critic
  Test::Kwalitee
  Test::CPAN::Changes
)
for section in "${blacklist[@]}"; do
  perl contrib/vendor/remove-section.pl "${section}" dist.ini ||
    err "Can't remove [$section]"
done

devdep_blacklist=(
  Test::Kwalitee
  Test::PerlTidy
  Test::Pod
)

perl contrib/vendor/remove-dev-requires.pl "${devdep_blacklist[@]}" dist.ini ||
  err "Can't strip DevelopRequires prereqs"
