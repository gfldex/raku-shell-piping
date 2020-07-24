use Test;
plan 8;

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
{ #6
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $errorer = Proc::Async.new: ‚t/bin/errorer‘;
    my @err;
    my @a;
    $source |» $errorer |» @a :stderr(@err);
    is-deeply @err[*;1][0,1,2], ("Lorem", "sit", "adipiscing"), ':stderr with Arrayish';
}
{ #7
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $errorer = Proc::Async.new: ‚t/bin/errorer‘;
    my @err;
    my @a;
    sub err-handler($stream, $msg) {
        @err.push: ($stream, $msg);
    }
    $source |» $errorer |» @a :stderr(&err-handler);
    is-deeply @err[*;1][0,1,2], ("Lorem", "sit", "adipiscing"), ':stderr with sub';
}
{ #8
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $errorer = Proc::Async.new: ‚t/bin/errorer‘;
    my @err;
    my @a;
    my $c = Channel.new;
    $c.Supply.tap: -> \v { @err.push: v }; 
    $source |» $errorer |» @a :stderr($c);
    $c.close;
    is-deeply @err[*;1][0,1,2], ("Lorem", "sit", "adipiscing"), ':stderr with channel';
}
