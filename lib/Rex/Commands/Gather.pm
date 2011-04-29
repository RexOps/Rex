#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Gather

=head1 DESCRIPTION

With this module you can gather hardware and software information.

=head1 SYNOPSIS

 operating_system_is("SuSE");


=head1 EXPORTED FUNCTIONS

=over 4

=cut


package Rex::Commands::Gather;

use strict;
use warnings;

use Rex::Hardware;
use Rex::Hardware::Host;

require Exporter;
use base qw(Exporter);

use vars qw(@EXPORT);

@EXPORT = qw(operating_system_is);

=item operating_system_is($string)

Will return 1 if the operating system is $string.
 
 task "is_it_suse", "server01", sub {
    if( operating_system_is("SuSE") ) {
       say "This is a SuSE system.";
    }
 };

=cut

sub operating_system_is {

   my ($os) = @_;

   my $host = Rex::Hardware::Host->get();

   if($host->{"operatingsystem"} eq $os) {
      return 1;
   }

   return 0;

}

=back

=cut

1;
