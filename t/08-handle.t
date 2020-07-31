use Test;
plan 3;

use Shell::Piping;

{ #1
    my $drain = Proc::Async.new: ‚t/bin/drain‘;
    my $h = open ‚t/data/lines.txt‘;
    my @a;
    $h |» $drain |» @a;

    is-deeply @a[0,1,2], ("1", "2", "3"), ‚feeding IO::Handle to Proc:Async‘
}
{ #2
    my $drain = Proc::Async.new: ‚t/bin/drain‘;
    my $p = ‚t/data/lines.txt‘.IO;
    my @a;
    $p |» $drain |» @a;

    is-deeply @a[0,1,2], ("1", "2", "3"), ‚feeding IO::Path to Proc:Async‘
}
class MockHandle is IO::Handle {
    has @.data;
    method write(\c) { @.data.push: c}
    method open(|) {}
}
{ #3
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $drain = Proc::Async.new: ‚t/bin/drain‘;
    my $mh = MockHandle.new;

    $source |» { .uc } |» $mh;
    is-deeply $mh.data».decode[0,1,2], ("LOREM\n", "IPSUM\n", "DOLOR\n"), ‚block feeding IO::Handle‘;
}
