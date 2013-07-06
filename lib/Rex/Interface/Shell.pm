#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Interface::Shell;

use strict;
use warnings;

use Rex::Logger;

sub create {
    my ($class, $shell) = @_;

    my $klass = "Rex::Interface::Shell::\u$shell";
    eval "use $klass";
    if ($@) {
        Rex::Logger::info("Can't load wanted shell: $shell. Using default shell.", "warn");
        Rex::Logger::info("If you want to help the development of Rex please report this issue in our Github issue tracker.", "warn");
        $klass = "Rex::Interface::Shell::Default";
        eval "use $klass";    
    }

    return $klass->new;
}

1;
