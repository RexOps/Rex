#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Function::can_run;

use strict;
use warnings;

# VERSION

use Rex -minimal;
use Rex::Function::Common;
use Rex::Helper::Path;

# create the function "can_run"
function "can_run", {

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
  # first parameter of the code reference is always a Rex controller object.
  # second, third, ... parameter are the real parameter the user passed to the
  # function call.
  sub {
  my @commands = @_;
  my $exec     = Rex::Interface::Exec->create;
  my $ret = $exec->can_run( [@commands] ); # use a new anon ref, so that we don't have drawbacks if some lower layers will manipulate things.

  # a function must return a hash reference
  # the return value that the function call should return to the "enduser"
  # is stored in "value"
  return { value => $ret, };
  };

1;

=head1 NAME

Rex::Function::Fs::is_file - Test if file exists

=head1 DESCRIPTION

With this is_file() function you can test if a file exists.

=head1 SYNOPSIS

 task "configure_something", "server01", sub {
   if(is_file "/etc/passwd") {
     run "something";
   }
 };

=cut
