#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::guestinfo;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Data::Dumper;
use Rex::Logger;
use Rex::Helper::Run;
use Rex::Helper::Path;
use Rex::Virtualization::LibVirt::iflist;
use Rex::Commands::Gather;
use Rex::Virtualization::LibVirt::info;
use Rex::Interface::File;
use Rex::Interface::Exec;
use JSON::MaybeXS;
require Rex::Commands::Run;

sub execute {
  my ( $class, $vmname ) = @_;

  unless ($vmname) {
    die("You have to define the vm name!");
  }

  Rex::Logger::debug("Getting info of guest: $vmname");

  my $info = Rex::Virtualization::LibVirt::info->execute($vmname);
  if ( $info->{State} eq "shut off" ) {
    return {};
  }

  my @ifaces;

  if ( Rex::Config::get_use_rex_kvm_agent
    && exists $info->{has_kvm_agent_on_port}
    && $info->{has_kvm_agent_on_port} )
  {

    my $got_ip = 0;

    while ( $got_ip == 0 ) {

      my $fh       = Rex::Interface::File->create();
      my $rnd_file = get_tmp_file;

      my $content = q|
        use strict;
        use warnings;

        unlink $0;

        use IO::Socket::INET;

        my $sock;

        while(! $sock) {
          $sock = IO::Socket::INET->new(PeerHost => '127.0.0.1', PeerPort => $ARGV[0], Proto => 'tcp');
          sleep 1;
        }

        my $got_info = 0;
        my $try = 0;
        while($got_info == 0) {
          eval {
            local $SIG{ALRM} = sub { die; };
            alarm 3;
            if($try >= 10) {
              exit 1;
            }

            $try++;
            print $sock "GET /network/devices\n";

            my $line = <$sock>;
            $line = <$sock>;
            $line =~ s/[\r\n]//gms;
            if($line =~ m/^\{"networkdevices/) {
              print "$line\n";
              $got_info++;
            }
            alarm 0;
          };
        }
      |;

      $fh->open( ">", $rnd_file );
      $fh->write($content);
      $fh->close;

      my $exec = Rex::Interface::Exec->create();
      my ($data) = $exec->exec("perl $rnd_file $info->{has_kvm_agent_on_port}");

      if ( $? == 1 ) {

        # can't connect to agent
        $info->{has_kvm_agent_on_port} = 0;
        last;
      }

      my $ref = decode_json($data);
      delete $ref->{networkconfiguration}->{lo};

      for my $net ( keys %{ $ref->{networkconfiguration} } ) {
        push @ifaces,
          {
          device => $net,
          %{ $ref->{networkconfiguration}->{$net} },
          };
      }

      if ( $ifaces[0]->{ip} ) {
        $got_ip++;
      }
      else {
        @ifaces = ();
        sleep 1;
      }
    }

  }

  if ( !$info->{has_kvm_agent_on_port} ) {

    my $ifs = Rex::Virtualization::LibVirt::iflist->execute($vmname);

    my $got_ip = 0;

    # search arp in different locations.
    # sometimes there is not PATH for normal users to /sbin commands.
    # and also arp can be in different locations.
    my $command =
      Rex::Commands::Run::can_run( "/sbin/arp", "/usr/sbin/arp", "arp" );

    while ( $got_ip < scalar( keys %{$ifs} ) ) {
      my %arp =
        map {
        my @x = ( $_ =~ m/\(([^\)]+)\) at ([^\s]+)\s/ );
        ( $x[1], $x[0] )
        } i_run "$command -an", fail_ok => 1;

      for my $if ( keys %{$ifs} ) {
        if ( exists $arp{ $ifs->{$if}->{mac} } && $arp{ $ifs->{$if}->{mac} } ) {
          $got_ip++;
          push @ifaces,
            {
            device => $if,
            ip     => $arp{ $ifs->{$if}->{mac} },
            %{ $ifs->{$if} }
            };
        }
      }

      sleep 1;
    }

  }

  return { network => \@ifaces, };
}

1;
