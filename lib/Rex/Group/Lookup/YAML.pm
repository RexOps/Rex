#
# (c) Jean-Marie RENOUARD <jmrenouard@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Group::Lookup::YAML - read hostnames and groups from a YAML file

=head1 DESCRIPTION

With this module you can define hostgroups out of an yaml file.

=head1 SYNOPSIS

 use Rex::Group::Lookup::YAML;
 groups_yaml "file.yml";


=head1 EXPORTED FUNCTIONS

=cut

package Rex::Group::Lookup::YAML;

use strict;
use warnings;

# VERSION

use Rex -base;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use YAML qw/LoadFile/;

@EXPORT = qw(groups_yaml);

=head2 groups_yaml($file)

With this function you can read groups from yaml files.

File Example:

webserver:
 - fe01
 - fe02
 - f03
backends:
 - be01
 - be02
 - f03
 
 groups_yaml($file);
 
 groups_yaml($file, create_all_group => TRUE);

=cut

sub groups_yaml {
  my ( $file, %option ) = @_;
  my %hash;

  my $hash = LoadFile($file);

  my %all_hosts;

  for my $k ( keys %{$hash} ) {
    my @servers;
    for my $servername ( @{ $hash->{$k} } ) {
      my $add = {};

      my $obj = Rex::Group::Entry::Server->new( name => $servername, %{$add} );

      $all_hosts{$servername} = $obj;
      push @servers, $obj;
    }

    group( "$k" => @servers );
  }

  if ( exists $option{create_all_group} && $option{create_all_group} ) {
    group( "all", values %all_hosts );
  }
}

1;
