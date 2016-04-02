use strict;
use warnings;

use Rex::Virtualization;
use Test::More tests => 6;
use Data::Dumper;
use Rex::Helper::Run;
use Rex::Commands::File;
use Rex::Commands::Fs;
use Rex::Commands::Run;

$::QUIET = 1;

my $image_format = "raw";

sub get_image_format { return $image_format; }

my $count_file = 0;
my $count_exec = 0;

no warnings 'redefine';

# TODO implement mocking

sub Rex::Commands::File::file {
  my ( $name, %params ) = @_;

  my $fmt = get_image_format();
  like $params{content}, qr|<driver name="qemu" type="$fmt"/>|,
    "Found file content for $fmt format.";
  $count_file++;
}

sub Rex::Commands::Run::can_run {
  return 1;
}

sub Rex::Commands::Fs::unlink {
  my ($file) = @_;
}

sub Rex::Helper::Run::i_run {
  my ($exec) = @_;

  if ( $exec =~ m/virsh.*capabilities/ ) {
    return eval { local (@ARGV) = ("t/issue/948/capabilities.xml"); <>; };
  }

  if ( $exec =~ m/^qemu\-img create/ ) {
    my $fmt = get_image_format();
    like $exec, qr/^qemu\-img create \-f $fmt/, "qemu-img created a raw image.";
    $count_exec++;
  }

  return "";
}

use warnings;

my $v = Rex::Virtualization->create("LibVirt");

$v->execute(
  "create", "test01",
  storage => [
    {
      file => "/mnt/data/libvirt/images/vm01.img",
      dev  => "vda",
    }
  ]
);

$image_format = "qcow2";

$v->execute(
  "create", "test01",
  storage => [
    {
      file        => "/mnt/data/libvirt/images/vm01.img",
      dev         => "vda",
      driver_type => "qcow2",
    }
  ]
);

is( $count_exec, 2, "Executed qemu-img 2 times." );
is( $count_file, 2, "Created virsh file 2 times." );

