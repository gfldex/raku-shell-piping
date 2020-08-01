#! /usr/bin/env raku

use v6.d;
use Shell::Piping;

my int $exitcode = 0;

sub MAIN(Str $where = ‚/tmp/.‘) {
    my @result;
    my @err;

    my $file = ‚/tmp/example.log‘.IO;

    px«find $where» |» { /a/ ?? $_ !! Nil } |» px<sort -r> |» @result
        :stderr($file) :done({$exitcode ⚛= 1 if .exitcodes; .stderr.close});

    .say for @result.head(10);

    if $exitcode {
        $*ERR.put: $file.IO.slurp;
    }

    exit $exitcode;
}
