#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::User::OpenWrt;

use strict;
use warnings;

# VERSION

use Rex::Logger;
require Rex::Commands;
use Rex::Helper::Run;
use Rex::Commands::Fs;
use Rex::Interface::File;
use Rex::Interface::Fs;
use Rex::Interface::Exec;
use Rex::Helper::Path;

use Rex::User::Linux;
use base qw(Rex::User::Linux);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub get_user {
  my ( $self, $user ) = @_;

  Rex::Logger::debug("Getting information for $user");
  my $o_data = i_run "perl -e 'print join(\";\", getpwnam(\"$user\"))'";
  chomp $o_data;
  my @data = split( /;/, $o_data );

  return (
    name     => $data[0],
    password => $data[1],
    uid      => $data[2],
    gid      => $data[3],
    comment  => $data[6],
    home     => $data[7],
    shell    => $data[8],
  );
}

sub user_groups {
  my ( $self, $user ) = @_;

  Rex::Logger::debug("Getting group membership of $user");

  my $data_str = i_run "/usr/bin/id -Gn $user", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error getting group list");
  }

  my $wantarray = wantarray();

  if ( defined $wantarray && !$wantarray ) {

    # arrayref
    return [ split( / /, $data_str ) ];
  }

  return split( / /, $data_str );
}

sub user_list {
  my $self = shift;

  Rex::Logger::debug("Getting user list");

  my $data_str = i_run "cut -d':' -f1 /etc/passwd", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error getting user list");
  }

  return split( /\n/, $data_str );
}

1;
