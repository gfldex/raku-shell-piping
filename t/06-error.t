use Test;
plan 5;

use Shell::Piping;

{ #1,2
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $errorer = Proc::Async.new: ‚t/bin/errorer‘;

    my $ex;
    my @a;

    $source |» $errorer |» @a :done({ $ex = .exitcode }) :quiet;

    is-deeply $ex[0,1], $(0,1), ‚exitcode is set‘;
    ok $ex, ‚exitcode is True‘;
}
{ #3,4
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $drain = Proc::Async.new: ‚t/bin/drain‘;

    my $ex;
    my @a;

    $source |» $drain |» @a :done({ $ex = .exitcode });

    is-deeply $ex[0,0], $(0,0), ‚exitcode is set‘;
    nok $ex, ‚exitcode is False‘;
}
{ #5
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $drain = Proc::Async.new: ‚t/bin/drain‘;

    my $pipe = $source |» $drain;
    isa-ok $pipe.exitcode, Failure, ‚Reading exitcode before pipe is done returns Failure.‘;
}
