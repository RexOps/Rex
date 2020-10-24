#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Box - Functions / Class to manage Virtual Machines

=head1 DESCRIPTION

This is a Module to manage Virtual Machines or Cloud Instances in a simple way. Currently it supports Amazon, KVM and VirtualBox.

Version <= 1.0: All these functions will not be reported.

=head1 SYNOPSIS

 use Rex::Commands::Box;
 
 set box => "VBox";
 
 group all_my_boxes => map { get_box($_->{name})->{ip} } list_boxes;
 
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

=cut

package Rex::Commands::Box;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use YAML;
use Data::Dumper;

use Rex::Commands -no => [qw/auth/];
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

Rex::Config->register_set_handler(
  "box",
  sub {
    my ( $type, @data ) = @_;
    Rex::Config->set( "box_type", $type );

    if ( ref( $data[0] ) ) {
      Rex::Config->set( "box_options", $data[0] );
    }
    else {
      Rex::Config->set( "box_options", {@data} );
    }
  }
);

=head2 new(name => $box_name)

Constructor if used in OO mode.

 my $box = Rex::Commands::Box->new(name => "box_name");

=cut

sub new {
  my $class = shift;
  return Rex::Box->create(@_);
}

=head2 box(sub {})

With this function you can create a new Rex/Box. The first parameter of this function is the Box object. With this object you can define your box.

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


=cut

sub box(&) {
  my $code = shift;

  #### too much black magic...
  #my ($caller_box) = do {
  #  my $pkg = caller();
  #  no strict 'refs';
  #  \*{ $pkg . "::box" };
  #};

  my $self = Rex::Box->create;

  #local( *$caller_box );
  #*$caller_box = \$self;

  $code->($self);

  #*$caller_box = \{}; # undef $box

  $self->import_vm();

  $self->provision_vm();

  return $self->ip;
}

=head2 list_boxes

This function returns an array of hashes containing all information that can be gathered from the hypervisor about the Rex/Box. This function doesn't start a Rex/Box.

 use Data::Dumper;
 task "get_infos", sub {
   my @all_boxes = list_boxes;
   print Dumper(\@all_boxes);
 };

=cut

sub list_boxes {
  my $box = Rex::Box->create;
  my @ret = $box->list_boxes;

  my $ref = LOCAL {
    if ( -f ".box.cache" ) {
      my $yaml_str = eval { local ( @ARGV, $/ ) = (".box.cache"); <>; };
      $yaml_str .= "\n";
      my $yaml_ref = Load($yaml_str);

      for my $box ( keys %{$yaml_ref} ) {
        my ($found_box) = grep { $_->{name} eq $box } @ret;
        if ( !$found_box ) {
          $yaml_ref->{$box} = undef;
          delete $yaml_ref->{$box};
        }
      }

      open( my $fh, ">", ".box.cache" ) or die($!);
      print $fh Dump($yaml_ref);
      close($fh);
    }

    if (wantarray) {
      return @ret;
    }

    return \@ret;
  };

  return @{$ref};
}

=head2 get_box($box_name)

This function tries to gather all information of a Rex/Box. This function also starts a Rex/Box to gather all information of the running system.

 use Data::Dumper;
 task "get_box_info", sub {
   my $data = get_box($box_name);
   print Dumper($data);
 };

=cut

sub get_box {
  my ($box_name) = @_;

  my $box = Rex::Box->create( name => $box_name );
  $box->info;

  if ( $box->status eq "stopped" ) {
    $box->start;
    $box->wait_for_ssh;
  }

  my $box_ip   = $box->ip;
  my $box_info = $box->info;

  return LOCAL {

    if ( -f ".box.cache" ) {
      Rex::Logger::debug("Loading box information of cache file: .box.cache.");
      my $yaml_str = eval { local ( @ARGV, $/ ) = (".box.cache"); <>; };
      $yaml_str .= "\n";
      my $yaml_ref = Load($yaml_str);
      %vm_infos = %{$yaml_ref};
    }

    if ( exists $vm_infos{$box_name} ) {
      return $vm_infos{$box_name};
    }

    my $pid = fork;
    if ( $pid == 0 ) {
      print
        "Gathering system information from $box_name.\nThis may take a while..";
      while (1) {
        print ".";
        sleep 1;
      }

      CORE::exit;
    }

    my $old_q = $::QUIET;
    $::QUIET = 1;

    eval {
      $vm_infos{$box_name} = run_task "Commands:Box:get_sys_info",
        on => $box_ip;
    } or do {
      $::QUIET = $old_q;
      print STDERR "\n";
      Rex::Logger::info(
        "There was an error connecting to your Box. Please verify the login credentials.\nERROR: $@\n",
        "warn"
      );
      Rex::Logger::debug(
        "You have to define login credentials before calling get_box()");

      # cleanup
      kill 9, $pid;
      CORE::exit(1);
    };
    $::QUIET = $old_q;

    for my $key ( keys %{$box_info} ) {
      $vm_infos{$box_name}->{$key} = $box_info->{$key};
    }

    open( my $fh, ">", ".box.cache" ) or die($!);
    print $fh Dump( \%vm_infos );
    close($fh);

    kill 9, $pid;
    print "\n";

    return $vm_infos{$box_name};
  };

}

=head2 boxes($action, @data)

With this function you can control your boxes. Currently there are 3 actions.

=over 4

=item init

This action can only  be used if you're using a YAML file to describe your Rex/Boxes.

 task "prepare_boxes", sub {
   boxes "init";
 };

=item start

This action start one or more Rex/Boxes.

 task "start_boxes", sub {
   boxes "start", "box1", "box2";
 };

=item stop

This action stop one or more Rex/Boxes.

 task "stop_boxes", sub {
   boxes "stop", "box1", "box2";
 };

=back

=cut

sub boxes {
  my ( $action, @data ) = @_;

  if ( substr( $action, 0, 1 ) eq "-" ) {
    $action = substr( $action, 1 );
  }

  if ( $action eq "init" ) {

    if ( -f ".box.cache" ) {
      unlink ".box.cache";
    }

    my $yaml_ref = $VM_STRUCT;

    my @vms;

    if ( ref $yaml_ref->{vms} eq "HASH" ) {
      for my $vm ( keys %{ $yaml_ref->{vms} } ) {
        push(
          @vms,
          {
            name => $vm,
            %{ $yaml_ref->{vms}->{$vm} }
          }
        );
      }
    }
    else {
      @vms = @{ $yaml_ref->{vms} };
    }

    my $box_vms = {};
    for my $vm_ref (@vms) {
      my $vm = $vm_ref->{name};
      box {
        my ($box) = @_;

        $box->name($vm);

        for my $key ( keys %{$vm_ref} ) {
          if ( ref( $vm_ref->{$key} ) eq "HASH" ) {
            $box->$key( %{ $vm_ref->{$key} } );
          }
          elsif ( ref( $vm_ref->{$key} ) eq "ARRAY" ) {
            $box->$key( @{ $vm_ref->{$key} } );
          }
          else {
            $box->$key( $vm_ref->{$key} );
          }
        }

        $box_vms->{$vm} = $box;
      };
    }

    return $box_vms;
  }

  if ( $action eq "stop" ) {
    for my $box (@data) {
      my $o = Rex::Commands::Box->new( name => $box );
      $o->stop;
    }
  }

  if ( $action eq "start" ) {
    for my $box (@data) {
      my $o = Rex::Commands::Box->new( name => $box );
      $o->start;
    }
  }

}

task 'get_sys_info', sub {
  return { get_system_information() };
}, { dont_register => 1, exit_on_connect_fail => 0 };

sub load_init_file {
  my ( $class, $file ) = @_;

  if ( !-f $file ) {
    die("Error: Wrong configuration file: $file.");
  }

  my $yaml_str = eval { local ( @ARGV, $/ ) = ($file); <>; };
  $yaml_str .= "\n";

  my $yaml_ref = Load($yaml_str);

  if ( !exists $yaml_ref->{type} ) {
    die("You have to define a type.");
  }

  my $type = ucfirst $yaml_ref->{type};
  set box_type => $type;

  # set special box options, like amazon out
  if ( exists $yaml_ref->{"\L$type"} ) {
    set box_options => $yaml_ref->{"\L$type"};
  }
  elsif ( exists $yaml_ref->{$type} ) {
    set box_options => $yaml_ref->{$type};
  }

  $VM_STRUCT = $yaml_ref;
}

sub import {
  my ( $class, %option ) = @_;

  if ( $option{init_file} ) {
    my $file = $option{init_file};
    $class->load_init_file($file);
    @_ = ($class);
  }

  __PACKAGE__->export_to_level( 1, @_ );
}

1;
