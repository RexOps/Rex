#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Master;

use strict;
use warnings;

use Rex;
use Rex::Logger;
use Rex::Master::FileList;
use Rex::Master::FileTransfer;

use Net::Server::PreFork;
use Socket qw(IPPROTO_TCP TCP_NODELAY);
use IO::Socket qw(:crlf);
use HTTP::Parser::XS qw(parse_http_request);


use constant READ_LEN     => 64 * 1024;
use constant READ_TIMEOUT => 3;
use constant WRITE_LEN    => 64 * 1024;

use base qw(Net::Server::PreFork);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = $proto->SUPER::new(@_);

   $self->{'config'} = { @_ };

   bless($self, $proto);

   return $self;
}

sub run {
   my $self = shift;

   Rex::Logger::debug("Starting rex-master server...");

   $self->SUPER::run(
      port                 => $self->{'config'}->{'port'}               || 7345,
      host                 => $self->{'config'}->{'host'}               || '',
      min_servers          => $self->{'config'}->{'min_servers'}        || 5,
      min_spare_servers    => $self->{'config'}->{'min_spare_servers'}  || 5,
      max_spare_servers    => $self->{'config'}->{'max_spare_servers'}  || 10,
      max_servers          => $self->{'config'}->{'max_servers'}        || 20,
      listen               => $self->{'config'}->{'backlog'}            || 1024,

      no_client_stdout     => 1,
      proto                => 'tcp',
      serialize            => 'flock',
   );

}


sub process_request {
   my $self = shift;
   my $c = $self->{'server'}->{'client'};
   setsockopt($c, IPPROTO_TCP, TCP_NODELAY, 1) or die($!);

   my %env = (
      REMOTE_ADDR => $self->{'server'}->{'peeraddr'},
      REMOTE_HOST => $self->{'server'}->{'peerhost'} || $self->{'server'}->{'peeraddr'},
      SERVER_NAME => $self->{'server'}->{'sockaddr'},
      SERVER_PORT => $self->{'server'}->{'sockport'},
      SCRIPT_NAME => ''
   );

   my $ret = parse_http_request($self->_fetch_header, \%env);
  
   if($ret == -1) {
      print STDERR "Request broken...\n";
      return;
   }

   if($env{'REQUEST_URI'} eq "/") {
      $ret = Rex::Master::FileList->run(\%env);
   }
   else {
      $ret = Rex::Master::FileTransfer->run(\%env);
   }

   my $len = length($ret);
   my $i;
   for($i = 0; $i < $len;) {
      syswrite $c, substr($ret, $i, WRITE_LEN);
      $i+=WRITE_LEN;
   }
}

sub _fetch_header {
   my $self = shift;

   my $in = '';
   eval {
      local $SIG{'ALRM'} = sub { die ('Request timed out.'); };
      local $/ = $CRLF;
      alarm( READ_TIMEOUT );
      my $cl = $self->{'server'}->{'client'};
      while(my $line = <$cl>) {
         $in .= $line;
         last if $in =~ m/$CRLF$CRLF/s;
      }
   };

   return $in;
}


1;
