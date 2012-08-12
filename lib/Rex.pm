#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex - Remote Execution

=head1 DESCRIPTION

(R)?ex is a small script to ease the execution of remote commands. You can write small tasks in a file named I<Rexfile>.

You can find examples and howtos on L<http://rexify.org/>

=head1 GETTING HELP

=over 4

=item * Web Site: L<http://rexify.org/>

=item * IRC: irc.freenode.net #rex

=item * Bug Tracker: L<https://rt.cpan.org/Dist/Display.html?Queue=Rex>

=item * Twitter: L<http://twitter.com/jfried83>

=back

=head1 Dependencies

=over 4

=item *

L<Net::SSH2>

=item *

L<Expect>

Only if you want to use the Rsync module.

=item *

L<DBI>

Only if you want to use the DB module.

=back

=head1 SYNOPSIS

 desc "Show Unix version";
 task "uname", sub {
     say run "uname -a";
 };

 bash# rex -H "server[01..10]" uname

See L<Rex::Commands> for a list of all commands you can use.

=head1 CLASS METHODS

=over 4

=cut


package Rex;

use strict;
use warnings;

use Net::SSH2;
use Rex::Logger;
use Rex::Cache;
use Rex::Interface::Connection;

our (@EXPORT,
      $VERSION,
      @CONNECTION_STACK,
      $GLOBAL_SUDO);

$VERSION = "0.31.4";

sub push_connection {
   push @CONNECTION_STACK, $_[0];
}

sub pop_connection {
   pop @CONNECTION_STACK;
   Rex::Logger::debug("Connections in queue: " . scalar(@CONNECTION_STACK));
}

=item get_current_connection

This function is deprecated since 0.28! See Rex::Commands::connection.

Returns the current connection as a hashRef.

=over 4

=item server

The server name

=item ssh

1 if it is a ssh connection, 0 if not.

=back

=cut

sub get_current_connection {

   # if no connection available, use local connect
   unless(@CONNECTION_STACK) {
      my $conn = Rex::Interface::Connection->create("Local");

      Rex::push_connection({
         conn   => $conn,
         ssh    => $conn->get_connection_object,
         cache => Rex::Cache->new(),
      });
   }

   $CONNECTION_STACK[-1];
}

=item is_ssh

Returns 1 if the current connection is a ssh connection. 0 if not.

=cut

sub is_ssh {
   if($CONNECTION_STACK[-1]) {
      my $ref = ref($CONNECTION_STACK[-1]->{"conn"});
      if($ref =~ m/SSH/) {
         return $CONNECTION_STACK[-1]->{"conn"}->get_connection_object();
      }
   }

   return 0;
}

=item is_sudo

Returns 1 if the current operation is executed within sudo. 

=cut
sub is_sudo {
   if($GLOBAL_SUDO) { return 1; }

   if($CONNECTION_STACK[-1]) {
      return $CONNECTION_STACK[-1]->{"use_sudo"};
   }

   return 0;
}

sub global_sudo {
   my ($on) = @_;
   $GLOBAL_SUDO = $on;

   # turn cache on
   $Rex::Cache::USE = 1;
}

=item get_sftp

Returns the sftp object for the current ssh connection.

=cut

sub get_sftp {
   if($CONNECTION_STACK[-1]) {
      return $CONNECTION_STACK[-1]->{"conn"}->get_fs_connection_object();
   }

   return 0;
}

sub get_cache {
   if($CONNECTION_STACK[-1]) {
      return $CONNECTION_STACK[-1]->{"cache"};
   }

   return Rex::Cache->new;
}

=item connect

Use this function to create a connection if you use Rex as a library.

 use Rex;
 use Rex::Commands::Run;
 use Rex::Commands::Fs;
   
 Rex::connect(
    server      => "remotehost",
    user        => "root",
    password    => "f00b4r",
    private_key => "/path/to/private/key/file",
    public_key  => "/path/to/public/key/file",
 );
    
 if(is_file("/foo/bar")) {
    print "Do something...\n";
 }
     
 my $output = run("upime");

=cut

sub connect {

   my ($param) = { @_ };

   my $server  = $param->{server};
   my $port    = $param->{port} || 22;
   my $timeout = $param->{timeout} || 5;
   my $user = $param->{"user"};
   my $pass = $param->{"password"};

   my $conn = Rex::Interface::Connection->create("SSH");

   $conn->connect(
      user     => $user,
      password => $pass,
      server   => $server,
      port     => $port,
      timeout  => $timeout,
   );

   unless($conn->is_connected) {
      die("Connetion error or refused.");
   }

   # push a remote connection
   Rex::push_connection({
      conn   => $conn,
      ssh    => $conn->get_connection_object,
      server => $server,
      cache => Rex::Cache->new(),
   });

   # auth unsuccessfull
   unless($conn->is_authenticated) {
      Rex::Logger::info("Wrong username or password. Or wrong key.", "warn");
      # after jobs

      die("Wrong username or password. Or wrong key.");
   }
}

sub deprecated {
   my ($func, $version, @msg) = @_;

   if($func) {
      Rex::Logger::info("The call to $func is deprecated.");
   }

   if(@msg) {
      for (@msg) {
         Rex::Logger::info($_);
      }
   }

   Rex::Logger::info("");

   Rex::Logger::info("Please rewrite your code. This function will disappear in (R)?ex version $version.");
   Rex::Logger::info("If you need assistance please join #rex on irc.freenode.net or our google group.");

}


sub import {
   my ($class, $what, $addition1) = @_;

   $what ||= "";

   my ($register_to, $file, $line) = caller;

   if($what eq "-base" || $what eq "base") {
      require Rex::Commands;
      Rex::Commands->import(register_in => $register_to);

      require Rex::Commands::Run;
      Rex::Commands::Run->import(register_in => $register_to);

      require Rex::Commands::Fs;
      Rex::Commands::Fs->import(register_in => $register_to);

      require Rex::Commands::File;
      Rex::Commands::File->import(register_in => $register_to);

      require Rex::Commands::Download;
      Rex::Commands::Download->import(register_in => $register_to);

      require Rex::Commands::Upload;
      Rex::Commands::Upload->import(register_in => $register_to);

      require Rex::Commands::Gather;
      Rex::Commands::Gather->import(register_in => $register_to);

      require Rex::Commands::Kernel;
      Rex::Commands::Kernel->import(register_in => $register_to);

      require Rex::Commands::Pkg;
      Rex::Commands::Pkg->import(register_in => $register_to);

      require Rex::Commands::Service;
      Rex::Commands::Service->import(register_in => $register_to);

      require Rex::Commands::Sysctl;
      Rex::Commands::Sysctl->import(register_in => $register_to);

      require Rex::Commands::Tail;
      Rex::Commands::Tail->import(register_in => $register_to);

      require Rex::Commands::Process;
      Rex::Commands::Process->import(register_in => $register_to);
   }
   elsif($what eq "-feature" || $what eq "feature") {
      # remove default task auth
      if($addition1 eq "0.31") {
         $Rex::TaskList::DEFAULT_AUTH = 0;
      }
   }

   # we are always strict
   strict->import;
}

=back

=head1 CONTRIBUTORS

Many thanks to the contributors for their work (alphabetical order).

=over 4

=item Alexandr Ciornii

=item Gilles Gaudin, for writing a french howto

=item Hiroaki Nakamura

=item Jean Charles Passard

=item Jeen Lee

=item Jose Luis Martinez

=item Samuele Tognini

=item Sascha Guenther

=item Sven Dowideit

=back

=cut

1;
