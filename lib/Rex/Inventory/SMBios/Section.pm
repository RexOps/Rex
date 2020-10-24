#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Inventory::SMBios::Section;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

require Exporter;
use base qw(Exporter);
use vars qw($SECTION @EXPORT);

@EXPORT  = qw(section);
$SECTION = {};

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub section {
  my ( $class, $section ) = @_;
  $SECTION->{$class} = $section;
}

sub has {
  my ( $class, $item, $is_array ) = @_;

  unless ( ref($item) eq "ARRAY" ) {
    my $_tmp = $item;
    $item = [$_tmp];
  }

  no strict 'refs';

  for my $_itm ( @{$item} ) {
    my ( $itm, $from );

    if ( ref($_itm) eq "HASH" ) {
      $itm  = $_itm->{key};
      $from = $_itm->{from};
    }
    else {
      $itm  = $_itm;
      $from = $_itm;
    }
    $itm =~ s/[^a-zA-Z0-9_]+/_/g;
    *{"${class}::get_\L$itm"} = sub {
      my $self = shift;
      return $self->get( $from, $is_array );
    };

    push( @{"${class}::items"}, "\L$itm" );
  }

  use strict;
}

sub dmi {

  my ($self) = @_;
  return $self->{"dmi"};

}

sub get {

  my ( $self, $key, $is_array ) = @_;
  return $self->_search_for( $key, $is_array );

}

sub get_all {

  my ($self) = @_;

  use Data::Dumper;
  my $r = ref($self);

  no strict 'refs';
  my @items = @{"${r}::items"};
  use strict;

  my $ret = {};
  for my $itm (@items) {
    my $f = "get_$itm";
    $ret->{$itm} = $self->$f();
  }

  return $ret;

}

sub dump {

  my ($self) = @_;

  require Data::Dumper;
  print Data::Dumper::Dumper(
    $self->dmi->get_tree( $SECTION->{ ref($self) } ) );

}

sub _search_for {
  my ( $self, $key, $is_array ) = @_;

  unless ( $self->dmi->get_tree( $SECTION->{ ref($self) } ) ) {

    #die $SECTION->{ref($self)} . " not supported";
    return;
  }

  my $idx = 0;
  for my $entry ( @{ $self->dmi->get_tree( $SECTION->{ ref($self) } ) } ) {
    my ($_key) = keys %{$entry};
    if ($is_array) {
      if ( $idx != $self->get_index() ) {
        ++$idx;
        next;
      }
    }

    if ( exists $entry->{$key} ) {
      return $entry->{$key};
    }
    else {
      return "";
    }
    ++$idx;
  }

  return "";
}

sub get_index {

  my ($self) = @_;
  return $self->{"index"} || 0;

}

1;

