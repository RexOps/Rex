#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Agent;

use strict;
use warnings;

use Net::Server::Daemonize qw(daemonize);
use LWP::UserAgent;

use vars qw($config);

sub run {
   my $class = shift;
   $config = { @_ };

   if($config->{'daemon'}) {
      daemonize(
         $config->{'user'} || 'root',
         $config->{'group'} || 'root',
         $config->{'pid_file'} || '/var/run/rex-agent.pid',
      );
   }

   unless(-d $config->{'cache_dir'}) {
      mkdir($config->{'cache_dir'});
   }

   while(1) {

      get_files();

      Rex::Logger::debug('Sleeping for ' . $config->{'interval'} . ' seconds.');
      sleep $config->{'interval'};

   }

}

sub get_files {

   Rex::Logger::debug("Requesting filelist...");

   my $base_url = 'http://' . $config->{'server'} . ':' . $config->{'port'} . '/';

   my $files = get($base_url);

   Rex::Logger::debug($files);

   my @files = split(/\n/, $files);

   for my $file (@files) {
   
      my ($dir) = ($file =~ m/^(.*)\//);
      if($dir && ! -d $config->{'cache_dir'} . "/" . $dir) {
         mkdir($config->{'cache_dir'} . "/" . $dir);
      }

      open(my $fh, ">", $config->{'cache_dir'} . '/' . $file) or die($!);
      print $fh get($base_url . $file);
      close($fh);

   }
}

sub get {
   my ($url) = @_;

   Rex::Logger::debug("Requesting: $url");

   my $ua = LWP::UserAgent->new;
   $ua->timeout($config->{'timeout'});
   $ua->env_proxy;

   my $response = $ua->get($url);

   if($response->is_success) {
      return $response->content;
   }
   else {
      Rex::Logger::debug("Error getting $url " . $response->status_line);
   }

}

1;
