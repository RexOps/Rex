#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Group::Lookup::INI - read host names and groups from an INI style file

=head1 DESCRIPTION

With this module you can define host groups in an INI style file.

=head1 SYNOPSIS

 use Rex::Group::Lookup::INI;
 groups_file 'file.ini';

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Group::Lookup::INI;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex -base;

require Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);

use Rex::Helper::INI;

@EXPORT = qw(groups_file);

=head2 groups_file($file)

With this function you can read groups from INI style files.

File example:

 # servers.ini
 [webservers]
 fe01
 fe02
    
 [backends]
 be[01..03]

It supports the same expressions as the L<group|Rex::Commands/group> command.

Since 0.42, it also supports custom host properties if the L<use_server_auth|Rex/use_server_auth> feature flag is enabled:

 # servers.ini
 [webservers]
 server01 user=root password=foob4r sudo=true services=apache,memcache

 # Rexfile
 use Rex -feature => ['use_server_auth'];

 task 'list_services', group => 'webservers', sub {
   say connection->server->option('services');
 }

=cut

sub groups_file {
  my ($file) = @_;

  my $section;
  my %hash;

  open( my $INI, "<", "$file" ) || die "Can't open $file: $!\n";
  my @lines = <$INI>;
  chomp @lines;
  close($INI);

  my $hash = Rex::Helper::INI::parse(@lines);

  for my $k ( keys %{$hash} ) {
    my @servers;
    for my $servername ( keys %{ $hash->{$k} } ) {
      my $add = {};
      if ( exists $hash->{$k}->{$servername}
        && ref $hash->{$k}->{$servername} eq "HASH" )
      {
        $add = $hash->{$k}->{$servername};
      }

      my $obj = Rex::Group::Entry::Server->new( name => $servername, %{$add} );
      push @servers, $obj;
    }

    group( "$k" => @servers );
  }
}

1;
