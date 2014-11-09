#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Group::Lookup::INI - read hostnames and groups from a INI style file

=head1 DESCRIPTION

With this module you can define hostgroups out of an ini style file.

=head1 SYNOPSIS

 use Rex::Group::Lookup::INI;
 groups_file "file.ini";
 

=head1 EXPORTED FUNCTIONS

=over 4

=cut

use strict;

package Rex::Group::Lookup::INI;

use warnings;

use Rex -base;

require Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);

use Rex::Helper::INI;

@EXPORT = qw(groups_file);

=item groups_file($file)

With this function you can read groups from ini style files.

File Example:

 [webserver]
 fe01
 fe02
 f03
    
 [backends]
 be01
 be02
 
 groups_file($file);

=cut

sub groups_file {
  my ($file) = @_;

  my $section;
  my %hash;

  open( my $INI, "$file" ) || die "Can't open $file: $!\n";
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

=back

=cut

1;
