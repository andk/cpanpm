use File::Rsync::Mirror::Recent;
my @rrr;
for my $tree ("authors","modules"){
    my $rrr = File::Rsync::Mirror::Recent->new
        (
         ignore_link_stat_errors => 1,
         localroot => "/home/ftp/pub/PAUSE/$tree",
         remote => "pause.perl.org::$tree/RECENT.recent",
         max_files_per_connection => 512,
         rsync_options =>
         {
          compress => 1,
          links => 1,
          times => 1,
          checksum => 0,
         },
         ttl => 12,
         verbose => 1,
         _runstatusfile => "recent-rmirror-state-$tree.yml",
         _logfilefordone => "recent-rmirror-donelog-$tree.log",
        );
    push @rrr, $rrr;
}
while (){
    my $ttgo = time + 23;
    for my $rrr (@rrr){
        $rrr->rmirror ( "skip-deletes" => 1 );
    }
    my $sleep = $ttgo - time;
    if ($sleep >= 1) {
        print STDERR "sleeping $sleep ... ";
        sleep $sleep;
    }
}
