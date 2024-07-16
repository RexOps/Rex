#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Inventory::Proc;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Inventory::Proc::Cpuinfo;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  $self->_read_proc();

  return $self;
}

sub _read_proc {
  my ($self) = @_;

  my $p_cpu = Rex::Inventory::Proc::Cpuinfo->new;

  $self->{__proc__} = { cpus => $p_cpu->get, };
}

sub get_cpus {
  my ($self) = @_;
  return $self->{__proc__}->{cpus};
}

1;
