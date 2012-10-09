#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Group::Lookup::File - read hostnames from a file.

=head1 DESCRIPTION

With this module you can define hostgroups out of a file.

=head1 SYNOPSIS

 use Rex::Group::Lookup::File;
 group "webserver" => lookup_file("./hosts.lst");
 

=head1 EXPORTED FUNCTIONS

=over 4

=cut
   
package Rex::Group::Lookup::File;
   
use strict;
use warnings;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);
    
@EXPORT = qw(lookup_file);


=item lookup_file($file)

With this function you can read hostnames from a file. Every hostname in one line.

 group "webserver"  => lookup_file("./webserver.lst");
 group "mailserver" => lookup_file("./mailserver.lst");

=cut
sub lookup_file {
   my ($file) = @_;

   open(my $fh, "<", $file) or die($!);
   my @content = grep { !/^#/ } <$fh>;
   close($fh);

   chomp @content;

   return @content;
}

=back

=cut

1;
