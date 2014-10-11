#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::import;

use strict;
use warnings;

use Rex::Logger;
use Rex::Helper::Run;
use Rex::Commands::Fs;
use File::Basename;
use Rex::Virtualization::LibVirt::create;
use Data::Dumper;

#
# %opt = (cpus => 2, memory => 512)
#
sub execute {
  my ( $class, $arg1, %opt ) = @_;

  unless ($arg1) {
    die("You have to define the vm name!");
  }

  my $dom = $arg1;
  Rex::Logger::debug( "importing: $dom -> " . $opt{file} );

  my $cwd = i_run "pwd";
  chomp $cwd;

  my $dir  = dirname $opt{file};
  my $file = "storage/" . basename $opt{file};
  mkdir "./storage";

  my $format = "qcow2";

  my @serial_devices;
  if ( exists $opt{serial_devices} ) {
    @serial_devices = @{ $opt{serial_devices} };
  }

  if ( $opt{file} =~ m/\.ova$/ ) {
    Rex::Logger::debug("Importing ova file. Try to convert with qemu-img");
    $file =~ s/\.[a-z]+$//;

    my @vmdk = grep { m/\.vmdk$/ } i_run "tar -C $dir -vxf $opt{file}";

    Rex::Logger::debug(
      "converting $cwd/tmp/$vmdk[0] -> $cwd/storage/$file.qcow2");
    i_run "qemu-img convert -O qcow2 $cwd/tmp/$vmdk[0] $cwd/$file.qcow2";

    if ( $? != 0 ) {
      Rex::Logger::info(
        "Can't import and convert $opt{file}. You qemu-img version seems not "
          . " to support this format.",
        "warn"
      );
      die("Error importing VM $opt{file}");
    }

    $file = "$file.qcow2";
  }
  else {
    Rex::Logger::debug("Importing kvm compatible file.");
    Rex::Logger::debug("Copying $opt{file} -> $file");
    cp $opt{file}, $file;
    if ( $file =~ m/\.gz$/ ) {
      Rex::Logger::debug("Extracting gzip'ed file $file");
      i_run "gunzip -q -f $file";
      $file =~ s/\.gz$//;
    }
  }

  my ($format_out) = grep { m/^file format:/ } i_run "qemu-img info $file";
  if ( $format_out =~ m/^file format: (.*)$/i ) {
    $format = $1;
  }

  my @network = values %{ $opt{__network} };
  if ( scalar @network == 0 ) {

    # create default network
    push @network,
      {
      type    => "network",
      network => "default",
      };
  }

  for (@network) {
    $_->{type} = "bridge"  if ( $_->{type} eq "bridged" );
    $_->{type} = "network" if ( $_->{type} eq "nat" );
    if ( $_->{type} eq "network" && !exists $_->{network} ) {
      $_->{network} = "default";
    }
  }

  Rex::Virtualization::LibVirt::create->execute(
    $dom,
    storage => [
      {
        file        => "$cwd/$file",
        dev         => "vda",
        driver_type => $format,
      },
    ],
    network        => \@network,
    serial_devices => \@serial_devices,
  );

  if ( exists $opt{__forward_port} ) {

    # currently not supported
    Rex::Logger::info(
      "Port-forwarding is currently not supported for KVM boxes.", "warn" );
  }

}

1;
