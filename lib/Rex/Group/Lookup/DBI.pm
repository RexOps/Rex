#
# (c) Jean-Marie RENOUARD <jmrenouard@gmail.com>
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Group::Lookup::DBI - read hostnames and groups from a DBI source

=head1 DESCRIPTION

With this module you can define hostgroups out of an DBI source.

=head1 SYNOPSIS

 use Rex::Group::Lookup::DBI;
 groups_dbi "dsn", "user", "password", "SQL request";
 

=head1 EXPORTED FUNCTIONS

=over 4

=cut
  
package Rex::Group::Lookup::DBI;
  
use strict;
use warnings;

use Rex -base;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use Rex::Helper::DBI;
@EXPORT = qw(groups_dbi);


=item groups_dbi($dsn, $user, $password, $sql)

 With this function you can read groups from DBI source.

=item Example:
 groups_dbi( 'DBI:mysql:rex;host=db01', 'username', 'password', "SELECT * FROM HOST");

=item Database sample for MySQL

 CREATE TABLE IF NOT EXISTS `HOST` (
`ID` int(11) NOT NULL,
`GROUP` varchar(255) DEFAULT NULL,
`HOST` varchar(255) NOT NULL,
PRIMARY KEY (`ID`)
);

=item Data sample for MySQL

 INSERT INTO `HOST` (`ID`, `GROUP`, `HOST`) VALUES
(1, 'db', 'db01'),
(2, 'db', 'db02'),
(3, 'was', 'was01'),
(4, 'was', 'was02');

=cut
sub groups_dbi {
  my ($dsn, $user, $pass, $sql) = @_;

  my $hash = Rex::Helper::DBI::perform_request($dsn, $user, $pass, $sql);

  my %group;
  my %all_hosts;
  for my $k (keys %{ $hash }) {
      my $add = {};
      my $rex_host=Rex::Group::Entry::Server->new(name =>$hash->{$k}->{'HOST'}, %{ $add });
      push @{ $group{$hash->{$k}->{'GROUP'}} }, $rex_host; 
      
      $all_hosts{$hash->{$k}->{'HOST'}}=$rex_host;
  }
  
  for my $g (  keys %group ) {
    group("$g" => @{$group{$g}} );
  }
  group ("all", values %all_hosts);
}

=back

=cut

1;
