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

use Rex::Commands -no => [qw/auth/];
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::Virtualization;


$|++;

################################################################################
# Setup Box-Type
################################################################################

set box => "VBox";

################################################################################
# BEGIN of class methods
################################################################################

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);
use Rex::Box;
#@EXPORT = qw(box $box);
@EXPORT = qw(box get_box_group_for);

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

sub get_group {
   my ($class, @boxnames) = @_;
   return (ref $class->new)->get_group();
}

sub get_box_group_for {
   return __PACKAGE__->get_group;
}

1;
