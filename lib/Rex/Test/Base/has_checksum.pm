#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Test::Base::has_checksum;

use strict;
use warnings;

# VERSION

use Rex -base;
use Digest::SHA;
use Rex::Commands::MD5;
use base qw(Rex::Test::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  my ( $pkg, $file ) = caller(0);

  return $self;
}

sub run_test {
  my ( $self, $file, $checksum, $algo, $computed ) = (shift, shift, shift, shift);
  $algo = lc($algo || '');
  my @supported = qw{md5 sha1 sha256};

  return $self->ok( 0, "has_content: $file not found" ) unless is_file($file);
  return $self->ok( 0, "unsupported hash algorithm $algo")
    unless grep { $algo eq $_ } @supported;

  $computed = md5( $file )      if ($algo eq 'md5');
  $computed = _sha( $file, $1 ) if ($algo =~ m/^sha(\d+)$/);

  $self->ok( $computed eq $checksum, "Checksum of $file is $checksum." );
}

sub _sha {
  my ($file, $algo) = (shift, shift);
  my $sha = Digest::SHA->new($algo);
  $sha->addfile($file);
  return $sha->hexdigest;
}


1;
