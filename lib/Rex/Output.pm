#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Output;

use strict;
use warnings;
BEGIN { IPC::Shareable->use }
use base 'Rex::Output::Base';

use vars qw($output_object);
my $handle = tie $output_object, 'IPC::Shareable', undef, { destroy => 1 };

sub get {
  my ( $class, $output_module ) = @_;

  return $output_object if ($output_object);

  return unless ($output_module);

  eval "use Rex::Output::$output_module;";
  if ($@) {
    die("Output Module ,,$output_module'' not found.");
  }

  my $output_class = "Rex::Output::$output_module";
  $output_object = $output_class->new;

  return $class;
}

sub _action {
  my ( $class, $action, @args ) = @_;

  return unless ( defined $output_object );
  $handle->shlock();
  $output_object->$action(@args);
  $handle->shunlock();
}

sub add {
  my $class = shift;

  return $class->_action( 'add', @_ );
}

sub error {
  my $class = shift;

  return $class->_action( 'error', @_ );
}

sub write {
  my $class = shift;

  return $class->_action( 'write', @_ );
}

1;
