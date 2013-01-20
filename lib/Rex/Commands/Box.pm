#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
=head1 NAME

Rex::Commands::Box - Functions / Class to manage Virtual Machines

=head1 DESCRIPTION

This is a Module to manage Virtual Machines or Cloud Instances in a simple way. Currently it supports only VirtualBox.

=head1 SYNOPSIS

 group vm => Rex::Commands::Box->get_group(qw/boxname1 boxname2/);
   
 task mytask => sub {
    
    box {
       my ($box) = @_;
       $box->name("boxname");
       $box->url("http://box.rexify.org/box/base-image.box");
          
       $box->network(1 => {
         type => "nat",
       });
           
       $box->network(1 => {
         type => "bridged",
         bridge => "eth0",
       });
          
       $box->forward_port(ssh => [2222, 22]);
          
       $box->share_folder(myhome => "/home/myuser");
          
       $box->auth(
         user => "root",
         password => "box",
       );
         
       $box->setup(qw/task_to_customize_box/);
       
    };
    
 };

=head1 EXPORTED FUNCTIONS

=over 4

=cut


package Rex::Commands::Box;

use strict;
use warnings;

use YAML;
use Data::Dumper;

use Rex::Commands -no => [qw/auth/];
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::Virtualization;
use Rex::Commands::Gather;


$|++;

################################################################################
# BEGIN of class methods
################################################################################

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT %vm_infos $VM_STRUCT);
use Rex::Box;
#@EXPORT = qw(box $box);
@EXPORT = qw(box list_boxes get_box boxes);

Rex::Config->register_set_handler("box", sub {
   my ($type, @data) = @_;
   Rex::Config->set("box_type", $type);

   if(ref($data[0])) {
      Rex::Config->set("box_options", $data[0]);
   }
   else {
      Rex::Config->set("box_options", { @data });
   }
});



=item new(name => $vmname)

Constructor if used in OO mode.

 my $box = Rex::Commands::Box->new(name => "vmname");

=cut

sub new {
   my $class = shift;
   return Rex::Box->create(@_);
}

sub box(&) {
   my $code = shift;

   #### too much black magic...
   #my ($caller_box) = do {
   #   my $pkg = caller();
   #   no strict 'refs';
   #   \*{ $pkg . "::box" };
   #};

   my $self = Rex::Box->create;

   #local( *$caller_box );
   #*$caller_box = \$self;

   $code->($self);

   #*$caller_box = \{}; # undef $box

   $self->import_vm();

   $self->provision_vm();
}

sub list_boxes {
   my $box = Rex::Box->create;
   my @ret = $box->list_boxes;

   if( -f ".box.cache") {
      my $yaml_str = eval { local(@ARGV, $/) = (".box.cache"); <>; };
      $yaml_str .= "\n";
      my $yaml_ref = Load($yaml_str);
      
      for my $box (keys %{ $yaml_ref }) {
         my ($found_box) = grep { $_->{name} eq $box } @ret;
         if(! $found_box) {
            $yaml_ref->{$box} = undef;
            delete $yaml_ref->{$box};
         }
      }

      open(my $fh, ">", ".box.cache") or die($!);
      print $fh Dump($yaml_ref);
      close($fh);
   }

   return @ret;
}

sub get_box {
   my ($box_name) = @_;
   my $box = Rex::Box->create(name => $box_name);

   $box->info;

   if($box->status eq "stopped") {
      $box->start;
      $box->wait_for_ssh;
   }

   if( -f ".box.cache") {
      Rex::Logger::debug("Loading box information of cache file: .box.cache.");
      my $yaml_str = eval { local(@ARGV, $/) = (".box.cache"); <>; };
      $yaml_str .= "\n";
      my $yaml_ref = Load($yaml_str);
      %vm_infos = %{ $yaml_ref };
   }

   if(exists $vm_infos{$box_name}) {
      return $vm_infos{$box_name};
   }

   my $pid = fork;
   if($pid == 0) {
      print "Gathering system information from $box_name.\nThis may take a while..";
      while(1) {
         print ".";
         sleep 1;
      }

      exit;
   }

   my $old_q = $::QUIET;
   $::QUIET = 1;


   $vm_infos{$box_name} = run_task "get_sys_info", on => $box->ip;
   $::QUIET = $old_q;

   my $box_info = $box->info;
   for my $key (keys %{ $box_info }) {
      $vm_infos{$box_name}->{$key} = $box_info->{$key};
   }

   kill 9, $pid;
   print "\n";

   open(my $fh, ">", ".box.cache") or die($!);
   print $fh Dump(\%vm_infos);
   close($fh);

   return $vm_infos{$box_name};
}

sub boxes {
   my ($action, @data) = @_;

   if(substr($action, 0, 1) eq "-") {
      $action = substr($action, 1);
   }

   if($action eq "init") {

      if(-f ".box.cache") {
         unlink ".box.cache";
      }

      my $yaml_ref = $VM_STRUCT;

      for my $vm (keys %{ $yaml_ref->{vms} }) {
         my $vm_ref = $yaml_ref->{vms}->{$vm};
         box {
            my ($box) = @_;

            $box->name($vm);

            for my $key (keys %{ $vm_ref }) {
               if(ref($vm_ref->{$key}) eq "HASH") {
                  $box->$key(%{ $vm_ref->{$key} });
               }
               elsif(ref($vm_ref->{$key}) eq "ARRAY") {
                  $box->$key(@{ $vm_ref->{$key} });
               }
               else {
                  $box->$key($vm_ref->{$key});
               }
            }
         };
      }
   }

   if($action eq "stop") {
      for my $box (@data) {
         my $o = Rex::Commands::Box->new(name => $box);
         $o->stop;
      }
   }

   if($action eq "start") {
      for my $box (@data) {
         my $o = Rex::Commands::Box->new(name => $box);
         $o->start;
      }
   }

}

Rex::TaskList->create()->create_task("get_sys_info", sub {
   return { get_system_information() };
}, { dont_register => 1 });

sub import {
   my ($class, %option) = @_;

   if($option{init_file}) {
      my $file = $option{init_file};

      if(! -f $file) {
         die("Error: Wrong configuration file: $file.");
      }

      my $yaml_str = eval { local(@ARGV, $/) = ($file); <>; };
      $yaml_str .= "\n";

      my $yaml_ref = Load($yaml_str);

      if(! exists $yaml_ref->{type}) {
         die("You have to define a type.");
      }

      my $type = ucfirst $yaml_ref->{type};
      set box_type => $type;

      # set special box options, like amazon out
      if(exists $yaml_ref->{"\L$type"}) {
         set box_options => $yaml_ref->{"\L$type"};
      }
      elsif(exists $yaml_ref->{$type}) {
         set box_options => $yaml_ref->{$type};
      }

      $VM_STRUCT = $yaml_ref;

      @_ = ($class);
   }

   __PACKAGE__->export_to_level(1, @_);
}

1;
