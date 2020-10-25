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

=cut

package Rex::Group::Lookup::DBI;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex -base;
use Carp;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use Rex::Helper::DBI;
@EXPORT = qw(groups_dbi);

=head2 groups_dbi($dsn, $user, $password, $sql)

With this function you can read groups from DBI source. Example:

 groups_dbi( 'DBI:mysql:rex;host=db01',
   user             => 'username',
   password         => 'password',
   sql              => "SELECT * FROM HOST",
   create_all_group => TRUE);

=head2 Database sample for MySQL

 CREATE TABLE IF NOT EXISTS `HOST` (
   `ID` int(11) NOT NULL,
   `GROUP` varchar(255) DEFAULT NULL,
   `HOST` varchar(255) NOT NULL,
   PRIMARY KEY (`ID`)
 );

=head2 Data sample for MySQL

 INSERT INTO `HOST` (`ID`, `GROUP`, `HOST`) VALUES
   (1, 'db', 'db01'),
   (2, 'db', 'db02'),
   (3, 'was', 'was01'),
   (4, 'was', 'was02');

=cut

sub groups_dbi {
  my ( $dsn, %option ) = @_; # $user, $pass, $sql) = @_;

  confess "You have to define the sql." if ( !exists $option{sql} );

  my $user = $option{user};
  my $pass = $option{password};
  my $sql  = $option{sql};

  my $hash = Rex::Helper::DBI::perform_request( $dsn, $user, $pass, $sql );

  my %group;
  my %all_hosts;
  for my $k ( keys %{$hash} ) {
    my $add = {};
    my $rex_host =
      Rex::Group::Entry::Server->new( name => $hash->{$k}->{'HOST'}, %{$add} );
    push @{ $group{ $hash->{$k}->{'GROUP'} } }, $rex_host;

    $all_hosts{ $hash->{$k}->{'HOST'} } = $rex_host;
  }

  for my $g ( keys %group ) {
    group( "$g" => @{ $group{$g} } );
  }

  if ( exists $option{create_all_group} && $option{create_all_group} ) {
    group( "all", values %all_hosts );
  }
}

1;
