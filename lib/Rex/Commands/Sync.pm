#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Sync - Sync directories

=head1 DESCRIPTION

This module can sync directories between your Rex system and your servers without the need of rsync.

=head1 SYNOPSIS

 use Rex::Commands::Sync;
    
 task "prepare", "mysystem01", sub {
    # upload directory recursively to remote system. 
    sync_up "/local/directory", "/remote/directory";
    
    sync_up "/local/directory", "/remote/directory", {
       # setting custom file permissions for every file
       files => {
          owner => "foo",
          group => "bar",
          mode  => 600,
       },
       # setting custom directory permissions for every directory
       directories => {
          owner => "foo",
          group => "bar",
          mode  => 700,
       },
    };
     
    # download a directory recursively from the remote system to the local machine
    sync_down "/remote/directory", "/local/directory";
 }; 

=cut
  
package Rex::Commands::Sync;

use strict;
use warnings;

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);

use Data::Dumper;
use Rex::Commands;
use Rex::Commands::Run;
use Rex::Commands::MD5;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Commands::Download;
use Rex::Helper::Path;

@EXPORT = qw(sync_up sync_down);

sub sync_up {
   my ($source, $dest, $options) = @_;

   $source = resolv_path($source);
   $dest   = resolv_path($dest);

   #
   # 0. normalize local path
   #
   $source = get_file_path($source, caller);

   #
   # first, get all files on source side
   #
   my @local_files = _get_local_files($source);

   #print Dumper(\@local_files);

   #
   # second, get all files from destination side
   #

   my @remote_files = _get_remote_files($dest);

   #print Dumper(\@remote_files);

   #
   # third, get the difference
   #

   my @diff = _diff_files(\@local_files, \@remote_files);

   #print Dumper(\@diff);

   #
   # fourth, upload the different files
   #

   for my $file (@diff) {
      my ($dir)        = ($file->{path} =~ m/(.*)\/[^\/]+$/);
      my ($remote_dir) = ($file->{name} =~ m/\/(.*)\/[^\/]+$/);

      my (%dir_stat, %file_stat);
      LOCAL {
         %dir_stat  = stat($dir);
         %file_stat = stat($file->{path});
      };

      # check for overwrites
      my %file_perm = (mode => $file_stat{mode});
      if(exists $options->{files} && exists $options->{files}->{mode}) {
         $file_perm{mode} = $options->{files}->{mode};
      }

      if(exists $options->{files} && exists $options->{files}->{owner}) {
         $file_perm{owner} = $options->{files}->{owner};
      }

      if(exists $options->{files} && exists $options->{files}->{group}) {
         $file_perm{group} = $options->{files}->{group};
      }

      my %dir_perm = (mode => $dir_stat{mode});
      if(exists $options->{directories} && exists $options->{directories}->{mode}) {
         $dir_perm{mode} = $options->{directories}->{mode};
      }

      if(exists $options->{directories} && exists $options->{directories}->{owner}) {
         $dir_perm{owner} = $options->{directories}->{owner};
      }

      if(exists $options->{directories} && exists $options->{directories}->{group}) {
         $dir_perm{group} = $options->{directories}->{group};
      }
      ## /check for overwrites

      if($remote_dir) {
         mkdir "$dest/$remote_dir",
            %dir_perm;
      }

      Rex::Logger::debug("(sync_up) Uploading $file->{path} to $dest/$file->{name}");
      if($file->{path} =~ m/\.tpl$/) {
         my $file_name = $file->{name};
         $file_name =~ s/\.tpl$//;

         file "$dest/" . $file_name,
            content => template($file->{path}),
            %file_perm;
      }
      else {
         file "$dest/" . $file->{name},
            source => $file->{path},
            %file_perm;
      }
   }

}

sub sync_down {
   my ($source, $dest, $options) = @_;

   $source = resolv_path($source);
   $dest   = resolv_path($dest);

   #
   # first, get all files on dest side
   #
   my @local_files = _get_local_files($dest);

   #print Dumper(\@local_files);

   #
   # second, get all files from source side
   #

   my @remote_files = _get_remote_files($source);

   #print Dumper(\@remote_files);

   #
   # third, get the difference
   #

   my @diff = _diff_files(\@remote_files, \@local_files);

   #print Dumper(\@diff);

   #
   # fourth, upload the different files
   #

   for my $file (@diff) {
      my ($dir)        = ($file->{path} =~ m/(.*)\/[^\/]+$/);
      my ($remote_dir) = ($file->{name} =~ m/\/(.*)\/[^\/]+$/);

      my (%dir_stat, %file_stat);
      %dir_stat  = stat($dir);
      %file_stat = stat($file->{path});

      LOCAL {
         if($remote_dir) {
            mkdir "$dest/$remote_dir",
               mode  => $dir_stat{mode};
         }
      };

      Rex::Logger::debug("(sync_down) Downloading $file->{path} to $dest/$file->{name}");
      download($file->{path}, "$dest/$file->{name}");

      LOCAL {
         chmod $file_stat{mode}, "$dest/$file->{name}";
      };
   }


}


sub _get_local_files {
   my ($source) = @_;

   if(! -d $source) { die("$source : no such directory."); }

   my @dirs = ($source);
   my @local_files;
   LOCAL {
      for my $dir (@dirs) {
         for my $entry (list_files($dir)) {
            next if($entry eq ".");
            next if($entry eq "..");
            if(is_dir("$dir/$entry")) {
               push(@dirs, "$dir/$entry");
               next;
            }

            my $name = "$dir/$entry";
            $name =~ s/^\Q$source\E//;
            push(@local_files, {
               name => $name,
               path => "$dir/$entry",
               md5  => md5("$dir/$entry"),
            });

         }
      }
   };

   return @local_files;
}

sub _get_remote_files {
   my ($dest) = @_;

   if(! is_dir($dest) ) { die("$dest : no such directory."); }

   my @remote_dirs = ($dest);
   my @remote_files;

   if(can_run("md5sum")) {
      # if md5sum executable is available
      # copy a script to the remote host so it is fast to scan
      # the directory.

      my $script = q|
use strict;
use warnings;
use Data::Dumper;

unlink $0;

my $dest = $ARGV[0];
my @dirs = ($dest);   
my @tree = ();

for my $dir (@dirs) {
   opendir(my $dh, $dir) or die($!);
   while(my $entry = readdir($dh)) {
      next if($entry eq ".");
      next if($entry eq "..");

      if(-d "$dir/$entry") {
         push(@dirs, "$dir/$entry");
         next;
      }

      my $name = "$dir/$entry";
      $name =~ s/^\Q$dest\E//;

      my $md5 = qx{md5sum $dir/$entry \| awk ' { print \$1 } '};

      chomp $md5;

      push(@tree, {
         path => "$dir/$entry",
         name => $name,
         md5  => $md5,
      });
   }
   closedir($dh);
}

print Dumper(\@tree);
      |;

      my $rnd_file = get_tmp_file;
      file $rnd_file, content => $script;
      my $content = run "perl $rnd_file $dest";
      $content =~ s/^\$VAR1 =//;
      my $ref = eval $content;
      @remote_files = @{ $ref };
   }
   else {
      # fallback if no md5sum executable is available
      for my $dir (@remote_dirs) {
         for my $entry (list_files($dir)) {
            next if($entry eq ".");
            next if($entry eq "..");
            if(is_dir("$dir/$entry")) {
               push(@remote_dirs, "$dir/$entry");
               next;
            }

            my $name = "$dir/$entry";
            $name =~ s/^\Q$dest\E//;
            push(@remote_files, {
               name => $name,
               path => "$dir/$entry",
               md5  => md5("$dir/$entry"),
            });
         }
      }
   }

   return @remote_files;
}

sub _diff_files {
   my ($files1, $files2) = @_;
   my @diff;

   for my $file1 (@{ $files1 }) {
      my @data = grep { ($_->{name} eq $file1->{name}) && ($_->{md5} eq $file1->{md5}) } @{ $files2 };
      if(scalar @data == 0) {
         push(@diff, $file1);
      }
   }

   return @diff;
}

1;
