#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
   
=head1 NAME

Rex::Commands::System - System specific functions

=head1 DESCRIPTION

With this Module you can manage some system specific configurations.

=head1 SYNOPSIS

 use Rex::Commands::System;
     

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::System;
   
use strict;
use warnings;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(default_language languages keyboard timezone);

=item default_language($lang)

Set the default language.

 default_language "en_US.UTF-8";

=cut
sub default_language {
}

=item language($lang1, $lang2, ...);

Set all available languages on a system.

 languages qw/en_US en_US.UTF-8/;

=cut
sub languages {
}

=item keyboard($keymap)

Set the keymap of a system.

 keyboard "de-latin1-nodeadkeys";

=cut
sub keyboard {
}

=item timezone($timezone)

Set the timezone of a system.

 timezone "UTC";

=cut
sub timezone {
}

1;
