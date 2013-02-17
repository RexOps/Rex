#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
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
   
package Rex::Group::Lookup::INI;
   
use strict;
use warnings;

use Rex -base;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);
    
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

   open (my $INI, "$file") || die "Can't open $file: $!\n";
   while (<$INI>) {
      chomp;
      s/\n|\r//g;

      if(/^#/ || /^;/ || /^$/ || /^\s*$/) {
         next;
      }

      if (/^\[(.*)\]/) {
         $section = $1;next;
      }
      push(@{$hash{$section}},$_);
   }
   close ($INI);

   for my $k (keys %hash) {
      group("$k" => @{$hash{$k}});
   }
}

=back

=cut

1;
