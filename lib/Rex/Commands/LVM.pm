#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Commands::LVM;
   
use strict;
use warnings;
   
require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);
    
@EXPORT = qw(pvs vgs lvs);

use Rex::Commands::Run;


sub pvs {
   
   my @lines = run "pvdisplay --units b --columns --separator '|' --noheadings";

   my @ret;
   for my $line (@lines) {
      chomp $line;
      $line =~ s/^\s+//g;
      my ($phy_vol, $vol_group, $format, $attr, $psize, $pfree) = split(/\|/, $line);
      $pfree =~ s/B$//;
      $psize =~ s/B$//;

      push(@ret, {
         physical_volume => $phy_vol,
         volume_group => $vol_group,
         format => $format,
         attributes => $attr,
         size => $psize,
         free => $pfree,
      });
   }

   return @ret;

}

sub vgs {

   my ($vg) = @_;


   my $cmd = "vgdisplay --units b --columns --separator '|' --noheadings -o 'pv_name,vg_name,vg_size,vg_free,vg_attr'";
   if($vg) {
      $cmd .= " $vg";
   }

   my @lines = run $cmd;

   my @ret;
   for my $line (@lines) {
      chomp $line;
      $line =~ s/^\s+//g;
      my ($pv_name, $vg_name, $vg_size, $vg_free, $vg_attr) = split(/\|/, $line);
      $vg_free =~ s/B$//;
      $vg_size =~ s/B$//;
      
      push(@ret, {
         physical_volume => $pv_name,
         volume_group => $vg_name,
         size => $vg_size,
         free => $vg_free,
         attributes => $vg_attr,
      });
   }

   return @ret;

}

sub lvs {

   my ($vg) = @_;

   my $cmd = "lvdisplay --units b --columns --separator '|' -o 'lv_name,lv_path,lv_attr,lv_size' --noheading";
   if($vg) {
      $cmd .= " " . $vg;
   }

   my @lines = run $cmd;

   my @ret;
   for my $line (@lines) {
      chomp $line;
      $line =~ s/^\s+//g;

      my($lv_name, $lv_path, $lv_attr, $lv_size) = split(/\|/, $line);
      $lv_size =~ s/B$//;
      push(@ret, {
         name => $lv_name,
         path => $lv_path,
         attributes => $lv_attr,
         size => $lv_size,
      });
   }

   return @ret;
}
   
1;
