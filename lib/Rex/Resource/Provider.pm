#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource::Provider;

use strict;
use warnings;

# VERSION

use Moose;
use Data::Dumper;

has __version__ => (
  is      => 'ro',
  isa     => 'Str',
  default => sub { "1" },
);

has name => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has config => (
  is       => 'ro',
  isa      => 'HashRef',
  required => 1,
);

has type => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has status => (
  is      => 'ro',
  isa     => 'Str',
  writer  => '_set_status',
  default => sub { 'unchanged' },
);

has fs => (
  is      => 'rw',
  isa     => 'Rex::Interface::Fs::Base',
  lazy    => 1,
  default => sub { return Rex::Interface::Fs->create },
);

has file => (
  is      => 'rw',
  isa     => 'Rex::Interface::File::Base',
  lazy    => 1,
  default => sub { return Rex::Interface::File->create },
);

has exec => (
  is      => 'rw',
  isa     => 'Rex::Interface::Exec::Base',
  lazy    => 1,
  default => sub { return Rex::Interface::Exec->create },
);

has message => (
  is      => 'ro',
  isa     => 'Str',
  writer  => '_set_message',
  default => sub { '' },
);

sub DEMOLISH {
  my ($self) = @_;
  $self->report;
}

sub report {
  my ($self) = @_;

  # TODO reporting
}

1;
