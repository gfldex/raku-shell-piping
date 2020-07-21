use Test;
plan 3;

use Shell::Piping;

{ #1
    my $drain = Proc::Async.new: ‚t/bin/drain‘;
    my $sup-out = ('a'..'z').reverse.Supply;
    my @a;
    $sup-out |» $drain |» @a;
    is-deeply @a[0,1,2], (<a b c>), ‚Supply |» Proc::Async‘;
}

{ #2
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $sup-in = Supplier.new;
    my @a;
    $sup-in.Supply.tap: { @a.push: $_ };
    $source |» $sup-in;
    is-deeply @a[0,1,2], ("Lorem", "ipsum", "dolor"), ‚Proc::Async |» Supplier‘;
}
{ #3
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $drain = Proc::Async.new: ‚t/bin/drain‘;
    my $sup-in = Supplier.new;
    my @a;
    $sup-in.Supply.tap: { @a.push: $_ };
    $source |» $drain |» $sup-in;
    is-deeply @a[0,1,2], ("", "Lorem", "adipiscing"), ‚Proc::Async |» Proc::Async |» Supply‘;
}
