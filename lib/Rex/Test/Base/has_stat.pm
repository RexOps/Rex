#
# (c) Robert Abraham <robert@adeven.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Test::Base::has_stat;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

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
    my $uid    = get_uid( $stats->{'owner'} );
    my $result = defined $uid ? $uid == $stat{'uid'} : 0;

    $self->ok( $result, "Owner of $path is $stats->{'owner'}" );
    $self->diag("has_stat: get_uid failed for $stats->{'owner'}.")
      unless defined $uid;
  }

  if ( defined( $stats->{'group'} ) ) {
    my $gid    = get_gid( $stats->{'group'} );
    my $result = defined $gid ? $gid == $stat{'gid'} : 0;

    $self->ok( $result, "Group of $path is $stats->{'group'}" );
    $self->diag("has_stat: get_gid failed for $stats->{'group'}.")
      unless defined $gid;
  }
}

1;
