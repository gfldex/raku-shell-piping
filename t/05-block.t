use Test;
plan 4;

use Shell::Piping;

{ #1
    my $source = Proc::Async.new(‚./t/bin/source‘);
    my @a;
    $source |» -> \v { @a.push: v };
    is-deeply @a[0,1,2], ("Lorem", "ipsum", "dolor"), ‚Proc::Async |» Block‘;
    
}
{ #2
    my $drain = Proc::Async.new(‚./t/bin/drain‘);
    my $s;
    $drain.stdout.lines.tap: { $s ~= $_ };
    { 2,4,8 … 2**8 } |» $drain;
    is $s, '128162256324648', ‚{ --> Iterable } |» $drain‘;
}
{ #2
    my $source = Proc::Async.new(‚./t/bin/source‘);
    my $drain = Proc::Async.new(‚./t/bin/drain‘);
    my @a;
    $drain.stdout.lines.tap: -> \v { @a.push: v };
    $source |» { .Str ~~ /a/ ?? .Str !! Nil } |» $drain;
    is-deeply @a, ["adipiscing", "aliqua.", "amet,", "labore", "magna"], ‚Proc::Async |» { --> Str | Nil } |» Proc::Async‘;
}
{ #4
    my $source = Proc::Async.new(‚./t/bin/source‘);
    my $middle = Proc::Async.new(‚./t/bin/drain‘);
    my @a;
    $source |» $middle |» -> \v { @a.push: v };
    is-deeply @a[0,1,2], ("", "Lorem", "adipiscing"), ‚Proc::Async |» Proc::Async |» Block‘;
    
}
