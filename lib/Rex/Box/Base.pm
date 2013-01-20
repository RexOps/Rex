#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Box::Base;

use strict;
use warnings;

use Rex::Commands -no => [qw/auth/];
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::Virtualization;
use Rex::Commands::SimpleCheck;

use LWP::UserAgent;
use Time::HiRes qw(tv_interval gettimeofday);
use File::Basename qw(basename);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   # default auth for rex boxes
   $self->{__auth} = {
      user        => Rex::Config->get_user(),
      password    => Rex::Config->get_password(),
      private_key => Rex::Config->get_private_key(),
      public_key  => Rex::Config->get_public_key(),
   };

   return $self;
}

=item info

Returns a hashRef of vm information.

=cut
sub info {
   my ($self) = @_;
   return $self->{info};
}

=item name($vmname)

Sets the name of the virtual machine.

=cut
sub name {
   my ($self, $name) = @_;
   $self->{name} = $name;
}

=item setup(@tasks)

Sets the tasks that should be executed as soon as the VM is available throu SSH.

=cut
sub setup {
   my ($self, @tasks) = @_;
   $self->{__tasks} = \@tasks;
}

=item import_vm()

This method must be overwriten and called at the end of the method.

 $self::SUPER->import_vm();

=cut
sub import_vm {
   my ($self) = @_;
   die("This method must be overwriten.");
}

=item stop()

Stops the VM.

=cut
sub stop {
   my ($self) = @_;
   vm shutdown => $self->{name};
}

=item start()

Starts the VM.

=cut
sub start {
   my ($self) = @_;
   vm start => $self->{name};

}

=item ip()

Return the ip:port to which rex will connect to.

=cut
sub ip { die("Must be implemented by box class.") }

=item status()

Returns the status of a VM.

Valid return values are "running" and "stopped".

=cut
sub status {
   my ($self) = @_;
   return vm status => $self->{name};
}

=item provision_vm([@tasks])

Execute's the given tasks on the VM.

=cut
sub provision_vm {
   my ($self, @tasks) = @_;
   die("This method must be overwriten.");
}

=item cpus($count)

Set the amount of CPUs for the VM.

=cut
sub cpus {
   my ($self, $cpus) = @_;
   $self->{cpus} = $cpus;
}

=item memory($memory_size)

Sets the memory of a VM in megabyte.

=cut
sub memory {
   my ($self, $mem) = @_;
   $self->{memory} = $mem;
}

=item network(%option)

Configure the network for a VM.

Currently it supports 2 modes. I<nat> and I<bridged>. Currently it supports only one network card.

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
   my ($self, %option) = @_;
   $self->{__network} = \%option;
}

=item url($url)

The URL where to download the Base VM Image. You can use self-made images or prebuild images from http://box.rexify.org/.

=cut
sub url {
   my ($self, $url, $force) = @_;
   $self->{url} = $url;
   $self->{force} = $force;
}

=item auth(%option)

Configure the authentication to the VM.

 $box->auth(
    user => $user,
    password => $password,
    private_key => $private_key,
    public_key => $public_key,
 );

=cut
sub auth {
   my ($self, %auth) = @_;
   $self->{__auth} = \%auth;
}

sub wait_for_ssh {
   my ($self, $ip, $port) = @_;

   print "Waiting for SSH to come up on $ip:$port.";
   while( ! is_port_open ($ip, $port) ) {
      print ".";
      sleep 1;
   }

   my $i=5;
   while($i != 0) {
      sleep 1;
      print ".";
      $i--;
   }

   print "\n";
}

sub _download {
   my ($self) = @_;

   my $filename = basename($self->{url});
   my $force = $self->{force} || FALSE;

   if(is_file("./tmp/$filename")) {
      Rex::Logger::info("File already downloaded. Please remove the file ./tmp/$filename if you want to download a fresh copy.");
   }
   else {
      $force = TRUE;
   }

   if($force) {
      Rex::Logger::info("Downloading $self->{url} to ./tmp/$filename");
      mkdir "tmp";
      if(Rex::is_local()) {
         my $ua = LWP::UserAgent->new();
         my $final_data = "";
         my $current_size = 0;
         my $current_modulo = 0;
         my $start_time = [gettimeofday()];
         open(my $fh, ">", "./tmp/$filename") or die($!);
         binmode $fh;
         my $resp = $ua->get($self->{url}, ':content_cb' => sub {
            my ($data, $response, $protocol) = @_;

            $current_size += length($data);

            my $content_length = $response->header("content-length");

            print $fh $data;

            my $current_time = [gettimeofday()];
            my $time_diff = tv_interval($start_time, $current_time);

            my $bytes_per_seconds = $current_size / $time_diff;

            my $mbytes_per_seconds = $bytes_per_seconds / 1024 / 1024;

            my $mbytes_current = $current_size / 1024 / 1024;
            my $mbytes_total = $content_length / 1024 / 1024;

            my $left_bytes = $content_length - $current_size;

            my $time_one_byte  = $time_diff / $current_size;
            my $time_all_bytes = $time_one_byte * ($content_length - $current_size);

            if( (($current_size / (1024 * 1024)) % (1024 * 1024)) > $current_modulo ) {
               print ".";
               $current_modulo++;

               if( $current_modulo % 10 == 0) {
                  printf(". %.2f MBytes/s (%.2f MByte / %.2f MByte) %.2f secs left\n", $mbytes_per_seconds, $mbytes_current, $mbytes_total, $time_all_bytes);
               }

            }

         });
         close($fh);

         print " done.\n";

      }
      else {
         run "wget -c -qO ./tmp/$filename $self->{url}";

         if($? != 0) {
            die("Downloading of $self->{url} failed. Please verify if wget is installed and if you have the right permissions to download this box.");
         }
      }
   }
}

=back

=cut


1;
