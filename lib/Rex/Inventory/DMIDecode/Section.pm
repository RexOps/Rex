#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Inventory::DMIDecode::Section;

use strict;
use warnings;


require Exporter;
use base qw(Exporter);
use vars qw($SECTION @EXPORT);

@EXPORT  = qw(section);
$SECTION = {};

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub section {
   my ($class, $section) = @_;
   $SECTION->{$class} = $section;
}

sub has {
   my ($class, $item) = @_;
   
   unless(ref($item) eq "ARRAY") {
      my $_tmp = $item;
      $item = [$_tmp];
   }

   no strict 'refs';

   for my $itm (@{$item}) {
      my $o_itm = $itm;
      $itm =~ s/[^a-zA-Z0-9_]+/_/g;
      *{"${class}::get_\L$itm"} = sub {
         my $self = shift;
         return $self->get($o_itm);
      };
   }

   use strict;
}

sub dmi {

   my ($self) = @_;
   return $self->{"dmi"};


}

sub get {

   my ($self, $key) = @_;
   return $self->_search_for($key);

}

sub dump {

   my ($self) = @_;

   require Data::Dumper;
   print Data::Dumper::Dumper($self->dmi->get_tree($SECTION->{ref($self)}));

}

sub _search_for {
   my ($self, $key) = @_;

   for my $entry (@{ $self->dmi->get_tree($SECTION->{ref($self)}) }) {
      my ($_key) = keys %{$entry};
      if($_key eq $key) {
         return $entry->{$key};
      }
   }
}



1;

