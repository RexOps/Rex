use Test::More tests => 5;

my %have_mods = (
  'Digest::HMAC_SHA1' => 1,
);

for my $m (keys %have_mods) {
  my $have_mod = 1;
  eval "use $m;";
  if($@) {
    $have_mods{$m} = 0;
  }
}

SKIP: {
  diag "You need Digest::HMAC_SHA1 module to use the Amazon Cloud module." unless $have_mod{'Digest::HMAC_SHA1'};
  skip "You need Digest::HMAC_SHA1 module to use the Amazon Cloud module.", 1 unless $have_mod{'Digest::HMAC_SHA1'};
  use_ok 'Rex::Cloud::Amazon';
}

use_ok 'Rex::Cloud::Base';
use_ok 'Rex::Cloud::Jiffybox';
use_ok 'Rex::Cloud::OpenStack';
use_ok 'Rex::Cloud';
