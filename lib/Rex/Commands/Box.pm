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
use vars qw(@EXPORT %vm_infos);
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
   $box->list_boxes;
}

sub get_box {
   my ($box_name) = @_;
   my $box = Rex::Box->create(name => $box_name);

   if($box->status eq "stopped") {
      $box->start;
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

   return $vm_infos{$box_name};
}

sub boxes {
   my ($action, @data) = @_;

   if(substr($action, 0, 1) eq "-") {
      $action = substr($action, 1);
   }

   if($action eq "init") {
      my $file = shift @data;
      if(! $file) {
         die("Error: You have to set a box configuration file.");
      }

      if(! -f $file) {
         die("Error: Wrong configuration file: $file.");
      }

      my $yaml_str = eval { local(@ARGV, $/) = ($file); <>; };
      $yaml_str .= "\n";

      my $yaml_ref = Load($yaml_str);

      my $type = Rex::Config->get("box_type") || "VBox";

      # set special box options, like amazon out
      if($yaml_ref->{"\L$type"}) {
         set box_options => $yaml_ref->{"\L$type"};
      }

      for my $vm (keys %{ $yaml_ref->{vms} }) {
         my $vm_ref = $yaml_ref->{vms}->{$vm};
         box {
            my ($box) = @_;

            $box->name($vm);

            for my $key (keys %{ $vm_ref }) {
               if(ref($vm_ref->{$key})) {
                  $box->$key(%{ $vm_ref->{$key} });
               }
               else {
                  $box->$key($vm_ref->{$key});
               }
            }
         };
      }
   }
}

Rex::TaskList->create()->create_task("get_sys_info", sub {
   return { get_system_information() };
}, { dont_register => 1 });

1;
