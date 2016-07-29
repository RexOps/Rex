#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Command::Fs::is_file;

use strict;
use warnings;

# VERSION

use Rex -minimal;
use Rex::Command::Common;
use Rex::Helper::Path;

# create the function "is_file"
function "is_file", {

  # export this function to the main namespace. so that it can be used
  # directly in Rexfile without the need to prepend the namespace of the module.
  export => 1,

  # define the parameter this function will have
  # rex is doing a type check here.
  # the keyname (here 'file') is yet without any meaning. but can be used
  # for automatic document generation or other things later.
  params_list => [
    file => { isa => 'Str', },
  ]
  },

  # this is the code that will be executed
  # first parameter of the code reference is always the Rex application object.
  # second, third, ... parameter are the real parameter the user passed to the
  # function call.
  sub {
  my ( $app, $file ) = @_;
  $file = resolv_path($file);

  my $fs  = Rex::Interface::Fs->create;
  my $ret = $fs->is_file($file);

  # a function must return a hash reference
  # the return value that the function call should return to the "enduser"
  # is stored in "value"
  return { value => $ret, };
  };

1;

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
