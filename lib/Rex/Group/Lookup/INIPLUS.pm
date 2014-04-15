#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Group::Lookup::INIPLUS - read hostnames and groups from a INI style file

=head1 DESCRIPTION

With this module you can define hostgroups out of an ini style file.
This is an enhanced version of Rex::Group::Lookup::INI 

=head1 SYNOPSIS

 use Rex::Group::Lookup::INIPLUS;
 groups_file "file.ini";
 

=head1 EXPORTED FUNCTIONS

=over 4

=cut
  
package Rex::Group::Lookup::INIPLUS;
  
use strict;
use warnings;

use Rex -base;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use Rex::Helper::INI;
@EXPORT = qw(groups_file reduce_parent);

=item groups_file($file)

With this function you can read groups from ini style files.

This version supports inherited group.
If groupname iscfollowed by ': parent', all elements within
having a group name are substitute by group element.

A group called 'all' is also generated containing all hosts.

File Example:

 [webserver]
 fe01
 fe02
 f03
    
 [backends]
 be01
 be02
 
 [farm : parent]
 backends
 webserver
 ref01
 ref02

 groups_file($file);

 group=>"all" contains all servers.

=cut
sub groups_file {
  my ($file) = @_;

  my $section;
  my %hash;

  open (my $INI, "$file") || die "Can't open $file: $!\n";
  my @lines = <$INI>;
  chomp @lines;
  close($INI);

  my $hash = Rex::Helper::INI::parse(@lines);
  
  reduce_parent($hash); 
  add_all_group($hash);
   
  for my $k (keys %{ $hash }) {
    my @servers;
    for my $servername (keys %{ $hash->{$k} }) {
      my $add = {};
      if(exists $hash->{$k}->{$servername} && ref $hash->{$k}->{$servername} eq "HASH") {
        $add = $hash->{$k}->{$servername};
      }

      my $obj = Rex::Group::Entry::Server->new(name => $servername, %{ $add });
      push @servers, $obj;
    }

    group("$k" => @servers);
  }
}

sub reduce_parent {
  my $hash=shift;
  my $i=0;
  for my $k (keys %{ $hash }) {
    if ($k =~ /(.*?):\s*parent/){
      for my $entry (keys %{ $hash->{$k} }) {
        $i=0;
        for my $entry_group(keys %{ $hash->{$entry}}) {
          ${$hash->{$1}}{$entry_group}=$entry_group;
          $i++;
        }
        if ($i==0) {
          ${$hash->{$1}}{$entry}=$entry;
          delete %{$hash}->{$entry};
        }
      }
      delete %{$hash}->{$k};
    }
  }
}

sub add_all_group {
  my $hash=shift;
  for my $k (keys %{ $hash }) {
    for my $entry_group(keys %{ $hash->{$k}}) {
      ${$hash->{'all'}}{$entry_group}=$entry_group;
    } 
  }
}
=back

=cut

1;
