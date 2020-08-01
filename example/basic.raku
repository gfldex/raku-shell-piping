#! /usr/bin/env raku

use v6.d;
use Shell::Piping;

my int $exitcode = 0;
my &RED = $*OUT.t ?? { „\e[31m$_\e[0m“ } !! { $_ };

sub MAIN(Str $where = ‚/tmp/.‘) {
    my @result;
    my @err;

    px«find $where» |» { /a/ ?? $_ !! Nil } |» px<sort -r> |» @result :stderr(@err) :done({$exitcode ⚛= 1 if .exitcodes});

    .say for @result.head(10);

    if $exitcode {
        $*ERR.put: @err».&RED.join(„\n“);
    }

    exit $exitcode;
}
