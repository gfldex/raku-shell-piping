use Test;
plan 8;

use Shell::Piping;

{ #1
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my @a;
    
    $source |» @a;
    is-deeply @a[0,1,2], ("Lorem", "ipsum", "dolor"), ‚Proc::Async |» Array‘;
}

{ #2
    my $drain = Proc::Async.new: ‚t/bin/drain‘;
    my @a = ('a'..'z').reverse;
    my @b;
    $drain.stdout.lines.tap: { @b.push: $_ };
    @a |» $drain;
    is-deeply @b[0,1,2], <a b c>, ‚Array |» Proc::Async‘;
}

{ #3
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $drain = Proc::Async.new: ‚t/bin/drain‘;
    my @a;
    $source |» $drain |» @a;
    is-deeply @a[0,1,2], ("", "Lorem", "adipiscing"), ‚Proc::Async |» Proc::Async |» Array‘;
}

class CustomObject {
    has @.a is rw;
    method push(\v) { @!a.push: v }
    method list { @!a.list }
}

{ #4
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $obj = CustomObject.new;

    $source |» $obj;
    is-deeply $obj.a[0,1,2], ("Lorem", "ipsum", "dolor"), ‚Proc::Async |» Arrayish‘;
}

{ #5
    my $drain = Proc::Async.new: ‚t/bin/drain‘;
    my $obj = CustomObject.new: :a(<3 2 1>);
    my @b;
    $drain.stdout.lines.tap: { @b.push: $_ };
    $obj |» $drain;
    is-deeply @b, ["1", "2", "3"], ‚Arrayish |» Proc::Async‘;
}
{ #6
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my @a;
    $source |» { .uc } |» @a;
    is-deeply @a[0,1,2], ("LOREM", "IPSUM", "DOLOR"), ‚Proc::Async |» Block |» Array‘;
}
{ #7
    my $source = Proc::Async.new: ‚t/bin/source‘;
    $source |» my (Whatever, $a, $b);
    is-deeply ($a, $b), ("magna", "aliqua."), ‚Proc::Async |» <left slurpy list deconstruction>‘;
}
{ #8
    my $source = Proc::Async.new: ‚t/bin/source‘;
    $source |» my ($a, $b, Whatever);
    is-deeply ($a, $b), ("Lorem", "ipsum"), ‚Proc::Async |» <right slurpy list deconstruction>‘;
}
