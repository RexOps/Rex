#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Commands::Iptables;

use strict;
use warnings;

require Exporter;
use Data::Dumper;

use base qw(Exporter);

use vars qw(@EXPORT);

use Rex::Commands::Sysctl;
use Rex::Commands::Run;

use Rex::Logger;

@EXPORT = qw(iptables is_nat_gateway iptables_list iptables_clear open_port);

sub open_port {

   my ($port, $option) = @_;

   my @opts;

   push(@opts, "t", "filter", "I", "INPUT");

   if(exists $option->{"dev"}) {
      push(@opts, "i", $option->{"dev"});
   }

   if(exists $option->{"proto"}) {
      push(@opts, "p", $option->{"proto"});
      push(@opts, "m", $option->{"proto"});
   }
   else {
      push(@opts, "p", "tcp");
      push(@opts, "m", "tcp");
   }

   if($port eq "all") {
      push(@opts, "j", "ACCEPT");
   }
   else {
      if(ref($port) eq "ARRAY") {
         for my $port_num (@{$port}) {
            open_port($port_num, $option);
         }
         return;
      }

      push(@opts, "dport", $port);
   }

   iptables @opts;

}

sub close_port {
}

sub redirect_port {
}

sub iptables {
   my (@params) = @_;

   my $cmd = "";
   my $n = -1;
   while( $params[++$n] ) {
      my ($key, $val) = @params[$n, $n++];

      if(ref($key) eq "ARRAY") {
         $cmd .= join(" ", @{$key});
         last;
      }

      if(length($key) == 1) {
         $cmd .= "-$key $val ";
      }
      else {
         $cmd .= "--$key=$val";
      }
   }

   if(can_run("iptables")) {
      run "iptables $cmd";

      if($? != 0) {
         Rex::Logger::info("Error setting iptable rule: $cmd");
      }
   }
   else {
      Rex::Logger::info("IPTables not found.");
   }
}

sub _iptables {
   
   my (%option) = @_;

   my $cmd = "/sbin/iptables ";

   my @iptables_option = ();

   if(exists $option{"open"}) {

      push(@iptables_option, { t => "filter" });
      push(@iptables_option, { I => "INPUT" });

      # net device given?
      if(exists $option{"dev"}) {
         push(@iptables_option, { i => $option{"dev"} });
      }

      # proto given?
      if(exists $option{"proto"}) {
         push(@iptables_option, { p => $option{"proto"} });
         push(@iptables_option, { m => $option{"proto"} });
      }
      else {
         push(@iptables_option, { p => "tcp" });
         push(@iptables_option, { m => "tcp" });
      }

      unless($option{"open"} eq "all") {
         for my $port (@{$option{"open"}}) {
            my @sub_option = @iptables_option;

            push(@sub_option, { dport => $port });
            push(@sub_option, { j => "ACCEPT" });

            _run_iptables (@sub_option);
         }
      }
      else {
         push(@iptables_option, { j => "ACCEPT" });
         _run_iptables (@iptables_option);
      }

   }
   elsif(exists $option{"close"}) {
      push(@iptables_option, { t => "filter" });
      push(@iptables_option, { A => "INPUT" });

      # net device given?
      if(exists $option{"dev"}) {
         push(@iptables_option, { i => $option{"dev"} });
      }

      # proto given?
      if(exists $option{"proto"}) {
         push(@iptables_option, { p => $option{"proto"} });
         push(@iptables_option, { m => $option{"proto"} });
      }
      else {
         push(@iptables_option, { p => "tcp" });
         push(@iptables_option, { m => "tcp" });
      }

      unless($option{"close"} eq "all") {
         for my $port (@{$option{"close"}}) {
            my @sub_option = @iptables_option;

            push(@sub_option, { dport => $port });
            push(@sub_option, { j => "REJECT" });
            push(@sub_option, { "reject-with" => "icmp-host-unreachable" });

            _run_iptables (@sub_option);
         }
      }
      else {
         push(@iptables_option, { j => "REJECT" });
         push(@iptables_option, { "reject-with" => "icmp-host-unreachable" });

         _run_iptables (@iptables_option);
      }

   }
   elsif(exists $option{"state"}) {
      push(@iptables_option, {t => "filter"});
      push(@iptables_option, {A => "INPUT"});

      if(exists $option{"dev"}) {
         push(@iptables_option, {i => $option{"dev"}});
      }

      push(@iptables_option, {m => "state"});
      push(@iptables_option, {state => $option{"state"}});
      
      if(exists $option{"accept"}) {
         push(@iptables_option, {j => "ACCEPT"});
      }
      
      if(exists $option{"drop"}) {
         push(@iptables_option, {j => "DROP"});
      }

      if(exists $option{"reject"}) {
         push(@iptables_option, {j => "REJECT"});
      }

      _run_iptables (@iptables_option);
   }
   elsif(exists $option{"redirect"}) {
      push(@iptables_option, {t => "nat"});

      if($option{"to"} =~ m/\:(\d+)$/) {

         push(@iptables_option, {I => "OUTPUT"});

         if(exists $option{"destination"}) {
            push(@iptables_option, {d => $option{"destination"} . "/32"});
         }

         if(exists $option{"source"}) {
            push(@iptables_option, {s => $option{"source"} . "/32"});
         }

         # proto given?
         if(exists $option{"proto"}) {
            push(@iptables_option, {p => $option{"proto"}});
            push(@iptables_option, {m => $option{"proto"}});
         }
         else {
            push(@iptables_option, {p => "tcp"});
            push(@iptables_option, {m => "tcp"});
         }

         if(exists $option{"dev"}) {
            push(@iptables_option, {o => $option{"dev"}});
         }

         push(@iptables_option, {dport => $option{"redirect"}});
         push(@iptables_option, {j => $option{"DNAT"}});
         push(@iptables_option, {"to-destination" => $option{"to"}});

      }
      else {

         push(@iptables_option, {I => "PREROUTING"});

         if(exists $option{"destination"}) {
            push(@iptables_option, {d => $option{"destination"} . "/32"});
         }

         if(exists $option{"source"}) {
            push(@iptables_option, {s => $option{"source"} . "/32"});
         }

         if(exists $option{"dev"}) {
            push(@iptables_option, {i => $option{"dev"}});
         }

         # proto given?
         if(exists $option{"proto"}) {
            push(@iptables_option, {p => $option{"proto"}});
            push(@iptables_option, {m => $option{"proto"}});
         }
         else {
            push(@iptables_option, {p => "tcp"});
            push(@iptables_option, {m => "tcp"});
         }

         push(@iptables_option, {dport => $option{"redirect"}});
         push(@iptables_option, {j => "REDIRECT"});
         push(@iptables_option, {"to-ports" => $option{"to"}});
      
      }

      _run_iptables (@iptables_option);
   }

}

sub is_nat_gateway {

   Rex::Logger::debug("Changing this system to a nat gateway.");

   if(can_run("ip")) {

      my @iptables_option = ();

      my ($default_line) = run "/sbin/ip r |grep ^default";
      my ($dev) = ($default_line =~ m/dev ([a-z0-9]+)/i);
      Rex::Logger::debug("Default GW Device is $dev");

      sysctl "net.ipv4.ip_forward" => 1;
      push(@iptables_option, {t => "nat"});
      push(@iptables_option, {A => "POSTROUTING"});
      push(@iptables_option, {o => $dev});
      push(@iptables_option, {j => "MASQUERADE"});

      _run_iptables (@iptables_option);

      return $?==0?1:0;

   }
   else {

      Rex::Logger::info("No /sbin/ip found.");

   }

}

sub iptables_list {
   
   my (%tables, $ret);

   my @lines = run "/sbin/iptables-save";

   my ($current_table);
   for my $line (@lines) {
      chomp $line;

      next if($line eq "COMMIT");
      next if($line =~ m/^#/);
      next if($line =~ m/^:/);

      if($line =~ m/^\*([a-z]+)$/) {
         $current_table = $1;
         $tables{$current_table} = [];
         next;
      }

      my @parts = grep { ! /^\s+$/ && ! /^$/ } split (/(\-\-?[^\s]+\s[^\s]+)/i, $line);

      my @option = ();
      for my $part (@parts) {
         my ($key, $value) = split(/\s/, $part, 2);
         $key =~ s/^\-+//;
         push(@option, {$key => $value});
      }

      push (@{$ret->{$current_table}}, \@option);

   }

   return $ret;
}

sub iptables_clear {

   for my $table (qw/nat mangle filter/) {
      iptables t => $table, F => '';
      iptables t => $table, X => '';
   }

   for my $p (qw/INPUT FORWARD OUTPUT/) {
      iptabls P => $p, ["ACCEPT"];
   }

}

sub _run_iptables {

   my (@options) = @_;

   my $cmd = "/sbin/iptables ";

   for my $option (values @options) {

      if(ref($option) eq "HASH") {
         my ($key) = keys %{$option};
         my ($value) = values %{$option};

         if(length($key) == 1) {
            $cmd .= " -$key $value ";
         }
         else {
            $cmd .= " --$key $value ";
         }

      }
      elsif(ref($option) eq "ARRAY") {
         $cmd .= join(" ", @{$option});
      }

   }

   run $cmd;

   if($? != 0) {
      Rex::Logger::info("Error setting iptable rule: $cmd");
   }

}


1;
