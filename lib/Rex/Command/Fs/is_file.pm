#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Command::Fs::is_file - Test if file exists

=head1 DESCRIPTION

With this is_file() function you can test if a file exists.

=head1 SYNOPSIS

 task "configure_something", "server01", sub {
   if(is_file "/etc/passwd") {
     run "something";
   }
 };

=cut

package Rex::Command::Fs::is_file;

use strict;
use warnings;

# VERSION

use Rex -minimal;
use Rex::Command::Common;
use Rex::Helper::Path;

# create the function "is_file" and export it to main namespace
# so that it can used directly in Rexfile without the need to prepend the
# namespace of the module.
function "is_file", { export => 1 }, sub {
  my ($file) = @_;
  $file = resolv_path($file);

  my $fs  = Rex::Interface::Fs->create;
  my $ret = $fs->is_file($file);

  # a function must return a hash reference
  # the return value that the function call should return to the "enduser"
  # is stored in "value"
  return { value => $ret, };
};

1;
