use Test;
plan 1;

use Shell::Piping;

{ #1
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $drain = Proc::Async.new: ‚t/bin/drain‘;

    my @a;
    $drain.stdout.lines.tap: { @a.push: $_ };

    $source |» $drain;
    is-deeply @a[0,1,2], ("", "Lorem", "adipiscing"), ‚Proc::Async |» Proc::Async‘;
}

{
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $drain = Proc::Async.new: ‚t/bin/drain‘;
    my $middle = Proc::Async.new: ‚t/bin/drain‘;

    my @a;
    $drain.stdout.lines.tap: { @a.push: $_ };

    $source |» $middle |» $drain;
    is-deeply @a[0,1,2], ("", "Lorem", "adipiscing"), ‚Proc::Async |» Proc::Async |» Proc::Async‘;
    
}
