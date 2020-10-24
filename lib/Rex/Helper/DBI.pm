#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Helper::DBI;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

BEGIN {
  use Rex::Require;
  DBI->require;
}

my %db_connections;

sub perform_request {

  my ( $dsn, $user, $pass, $req ) = @_;

  $user ||= "";
  $pass ||= "";

  my $con_key = "$dsn-$user-$pass";

  if ( !exists $db_connections{$dsn} ) {
    $db_connections{$con_key} = DBI->connect( $dsn, $user, $pass )
      or die("Cannot connect: $DBI::errstr\n");
  }

  my %res;

  my $sth = $db_connections{$con_key}->prepare($req);
  $sth->execute();

  my $i = 1;
  while ( my $ref = $sth->fetchrow_hashref() ) {
    $res{$i} = $ref;
    $i++;
  }

  return \%res;
}

1;
