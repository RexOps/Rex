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
  my ( $self, $file, $stats ) = @_;

  if ( !is_file($file) ) {
    $self->ok( 0, "Stat: file $file not found" );
    return;
  }

  my %stat = stat $file;

  if ( defined( $stats->{'owner'} ) ) {
    my $uid = get_uid( $stats->{'owner'} );
    $self->ok( $uid == $stat{'uid'}, "Owner is $stats->{'owner'}" );
  }

  if ( defined( $stats->{'group'} ) ) {
    my $gid = get_gid( $stats->{'group'} );
    $self->ok( $gid == $stat{'gid'}, "Group is $stats->{'group'}" );
  }
}

1;
