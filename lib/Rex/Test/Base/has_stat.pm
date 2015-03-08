#
# (c) Robert Abraham <robert@adeven.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Test::Base::has_stat;

use strict;
use warnings;

# VERSION

use Rex -base;
use base qw(Rex::Test::Base);
use Rex::Commands::Fs;
use Rex::Commands::User;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  my ( $pkg, $file ) = caller(0);

  return $self;
}

sub run_test {
  my ( $self, $path, $stats ) = @_;

  my %stat;
  eval { %stat = stat $path; };

  if ($@) {
    $self->ok( 0, "has_stat: cannot stat $path." );
    $self->diag($@);
    return;
  }

  if ( defined( $stats->{'owner'} ) ) {
    my $uid = get_uid( $stats->{'owner'} );
    $self->ok( $uid == $stat{'uid'}, "Owner of $path is $stats->{'owner'}" );
  }

  if ( defined( $stats->{'group'} ) ) {
    my $gid = get_gid( $stats->{'group'} );
    $self->ok( $gid == $stat{'gid'}, "Group of $path is $stats->{'group'}" );
  }
}

1;
