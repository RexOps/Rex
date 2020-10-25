#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Box::Base - Rex/Boxes Base Module

=head1 DESCRIPTION

This is a Rex/Boxes base module.

=head1 METHODS

These methods are shared across all other Rex::Box modules.

=cut

package Rex::Box::Base;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Commands -no => [qw/auth/];
use Rex::Helper::Run;
use Rex::Commands::Fs;
use Rex::Commands::Virtualization;
use Rex::Commands::SimpleCheck;
use Rex::Helper::IP;

BEGIN {
  LWP::UserAgent->use;
}

use Time::HiRes qw(tv_interval gettimeofday);
use File::Basename qw(basename);
use Data::Dumper;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  # default auth for rex boxes
  $self->{__auth} = {
    user        => Rex::Config->get_user(),
    password    => Rex::Config->get_password(),
    private_key => Rex::Config->get_private_key(),
    public_key  => Rex::Config->get_public_key(),
  };

  # for box this is needed, because we have changing ips
  Rex::Config->set_openssh_opt(
    StrictHostKeyChecking => "no",
    UserKnownHostsFile    => "/dev/null",
    LogLevel              => "QUIET"
  );

  return $self;
}

=head2 info

Returns a hashRef of vm information.

=cut

sub info {
  my ($self) = @_;
  return $self->{info};
}

=head2 name($vmname)

Sets the name of the virtual machine.

=cut

sub name {
  my ( $self, $name ) = @_;
  $self->{name} = $name;
}

=head2 setup(@tasks)

Sets the tasks that should be executed as soon as the VM is available through SSH.

=cut

=head2 storage('path/to/vm/disk')

Sets the disk path of the virtual machine. Works only on KVM

=cut

sub storage {
  my ( $self, $folder ) = @_;

  $self->{storage_path} = $folder;
}

sub setup {
  my ( $self, @tasks ) = @_;
  $self->{__tasks} = \@tasks;
}

=head2 import_vm()

This method must be overwritten by the implementing class.

=cut

sub import_vm {
  my ($self) = @_;
  die("This method must be overwritten.");
}

=head2 stop()

Stops the VM.

=cut

sub stop {
  my ($self) = @_;
  $self->info;
  vm shutdown => $self->{name};
}

=head2 destroy()

Destroy the VM.

=cut

sub destroy {
  my ($self) = @_;
  $self->info;
  vm destroy => $self->{name};
}

=head2 start()

Starts the VM.

=cut

sub start {
  my ($self) = @_;
  $self->info;
  vm start => $self->{name};

}

=head2 ip()

Return the ip:port to which rex will connect to.

=cut

sub ip { die("Must be implemented by box class.") }

=head2 status()

Returns the status of a VM.

Valid return values are "running" and "stopped".

=cut

sub status {
  my ($self) = @_;
  return vm status => $self->{name};
}

=head2 provision_vm([@tasks])

Executes the given tasks on the VM.

=cut

sub provision_vm {
  my ( $self, @tasks ) = @_;

  if ( !@tasks ) {
    @tasks = @{ $self->{__tasks} } if ( exists $self->{__tasks} );
  }

  $self->wait_for_ssh();

  for my $task (@tasks) {
    my $task_o = Rex::TaskList->create()->get_task($task);
    if ( !$task_o ) {
      die "Task $task not found.";
    }

    $task_o->set_auth( %{ $self->{__auth} } );
    Rex::Commands::set( "box_object", $self );
    $task_o->run( $self->ip );
    Rex::Commands::set( "box_object", undef );
  }
}

=head2 cpus($count)

Set the amount of CPUs for the VM.

=cut

sub cpus {
  my ( $self, $cpus ) = @_;
  $self->{cpus} = $cpus;
}

=head2 memory($memory_size)

Sets the memory of a VM in megabyte.

=cut

sub memory {
  my ( $self, $mem ) = @_;
  $self->{memory} = $mem;
}

=head2 network(%option)

Configure the network for a VM.

Currently it supports 2 modes: I<nat> and I<bridged>. Currently it supports only one network card.

 $box->network(
   1 => {
     type => "nat",
   },
 }
 
 $box->network(
   1 => {
     type => "bridged",
     bridge => "eth0",
   },
 );

=cut

sub network {
  my ( $self, %option ) = @_;
  $self->{__network} = \%option;
}

=head2 forward_port(%option)

Set ports to be forwarded to the VM. This is not supported by all Box providers.

 $box->forward_port(
   name => [$from_host_port, $to_vm_port],
   name2 => [$from_host_port_2, $to_vm_port_2],
   ...
 );

=cut

sub forward_port {
  my ( $self, %option ) = @_;
  $self->{__forward_port} = \%option;
}

=head2 list_boxes

List all available boxes.

=cut

sub list_boxes {
  my ($self) = @_;

  my $vms = vm list => "all";

  return @{$vms};
}

=head2 url($url)

The URL where to download the Base VM Image. You can use self-made images or prebuild images from L<http://box.rexify.org/>.

=cut

sub url {
  my ( $self, $url, $force ) = @_;
  $self->{url}   = $url;
  $self->{force} = $force;
}

=head2 auth(%option)

Configure the authentication to the VM.

 $box->auth(
   user => $user,
   password => $password,
   private_key => $private_key,
   public_key => $public_key,
 );

=cut

sub auth {
  my ( $self, %auth ) = @_;
  if (%auth) {
    $self->{__auth} = \%auth;
  }
  else {
    return $self->{__auth};
  }
}

=head2 options(%option)

Addition options for boxes

 $box->options(
   opt1 => $val1,
   opt2 => $val2,
 );

=cut

sub options {
  my ( $self, %opt ) = @_;
  if (%opt) {
    $self->{__options} = \%opt;
  }
  else {
    return $self->{__options};
  }
}

sub wait_for_ssh {
  my ( $self, $ip, $port ) = @_;

  if ( !$ip ) {
    ( $ip, $port ) = Rex::Helper::IP::get_server_and_port( $self->ip, 22 );
  }

  print "Waiting for SSH to come up on $ip:$port.";
  while ( !is_port_open( $ip, $port ) ) {
    print ".";
    sleep 1;
  }

  print "\n";
}

sub _download {
  my ($self) = @_;

  my $filename = basename( $self->{url} );
  my $force    = $self->{force} || FALSE;
  my $fs       = Rex::Interface::Fs->create;

  if ( $fs->is_file("./tmp/$filename") ) {
    Rex::Logger::info(
      "File already downloaded. Please remove the file ./tmp/$filename if you want to download a fresh copy."
    );
  }
  else {
    $force = TRUE;
  }

  if ($force) {
    Rex::Logger::info("Downloading $self->{url} to ./tmp/$filename");
    mkdir "tmp";
    if ( Rex::is_local() ) {
      my $ua = LWP::UserAgent->new();
      $ua->env_proxy;
      my $final_data     = "";
      my $current_size   = 0;
      my $current_modulo = 0;
      my $start_time     = [ gettimeofday() ];
      open( my $fh, ">", "./tmp/$filename" )
        or die("Failed to open ./tmp/$filename for writing: $!");
      binmode $fh;
      my $resp = $ua->get(
        $self->{url},
        ':content_cb' => sub {
          my ( $data, $response, $protocol ) = @_;

          $current_size += length($data);

          my $content_length = $response->header("content-length");

          print $fh $data;

          my $current_time = [ gettimeofday() ];
          my $time_diff    = tv_interval( $start_time, $current_time );

          my $bytes_per_seconds = $current_size / $time_diff;

          my $mbytes_per_seconds = $bytes_per_seconds / 1024 / 1024;

          my $mbytes_current = $current_size / 1024 / 1024;
          my $mbytes_total   = $content_length / 1024 / 1024;

          my $left_bytes = $content_length - $current_size;

          my $time_one_byte = $time_diff / $current_size;
          my $time_all_bytes =
            $time_one_byte * ( $content_length - $current_size );

          if ( ( ( $current_size / ( 1024 * 1024 ) ) % ( 1024 * 1024 ) ) >
            $current_modulo )
          {
            print ".";
            $current_modulo++;

            if ( $current_modulo % 10 == 0 ) {
              printf(
                ". %.2f MBytes/s (%.2f MByte / %.2f MByte) %.2f secs left\n",
                $mbytes_per_seconds, $mbytes_current,
                $mbytes_total,       $time_all_bytes
              );
            }

          }

        }
      );
      close($fh);

      if ( $resp->is_success ) {
        print " done.\n";
      }
      else {
        Rex::Logger::info( "Error downloading box image.", "warn" );
        unlink "./tmp/$filename";
      }

    }
    else {
      i_exec "wget", "-c", "-qO", "./tmp/$filename", $self->{url};

      if ( $? != 0 ) {
        die(
          "Downloading of $self->{url} failed. Please verify if wget is installed and if you have the right permissions to download this box."
        );
      }
    }
  }
}

1;
