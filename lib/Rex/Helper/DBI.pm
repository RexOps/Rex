#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
  
package Rex::Helper::DBI;

use strict;
use warnings;
use DBI;

use String::Escape 'string2hash';


sub perform_request {

  my ($dsn, $user, $pass, $req) = @_;
  
  my $dbh=DBI->connect($dsn, $user,$pass) or die("Cannot connect: $DBI::errstr\n") ;

  my %res;

  my $sth = $dbh->prepare($req);
  $sth->execute();

  my $i=1;
  while ( my $ref = $sth->fetchrow_hashref() ) 
  {
    $res{$i}=$ref;
    $i++;
  }

  $dbh->disconnect;
  return \%res;
}

1;
