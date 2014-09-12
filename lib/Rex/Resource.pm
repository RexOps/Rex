#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
   
package Rex::Resource;

use strict;
use warnings;

our $INSIDE_RES = 0;
our @CURRENT_RES;

sub new {
  my $that = shift;
  my $proto = ref($that) || $that;
  my $self = { @_ };

  bless($self, $proto);

  return $self;
}

sub name { (shift)->{name}; }
sub type { (shift)->{type}; }

sub call {
  my ($self, $name, %params) = @_;
  $INSIDE_RES = 1;
  push @CURRENT_RES, $self;

  $self->{res_name} = $name;

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => $self->type, name => $name );

  $self->{cb}->(\%params);

  if($self->changed) {
    Rex::get_current_connection()->{reporter}->report(
      changed => 1,
      message => $self->name . " changed.",
    );
  }
  else {
    Rex::get_current_connection()->{reporter}->report(
      changed => 0,
      message => $self->name . " not changed.",
    );
  }

  if(exists $params{on_change} && $self->changed) {
    $params{on_change}->();
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => $self->type, name => $name );

  $INSIDE_RES = 0;
  pop @CURRENT_RES;
}

sub changed {
  my ($self, $changed) = @_;

  if(defined $changed) {
    $self->{changed} = $changed;
  }
  else {
    return $self->{changed};
  }
}

1;
