use Test;
plan 3;

use Shell::Piping;

{ # 1
    my $source = Proc::Async.new(‚./t/bin/source‘);
    my $drain = Proc::Async.new(‚./t/bin/drain‘);
    
    my $c = Channel.new;
    Promise.in(1).then: {
        for ('a'..'z').pick(30) {
            $c.send: .Str;
        }
        $c.close;
    };
    
    my @a;
    
    $c |» $drain |» @a;
    
    is-deeply @a[0,1,2], <a b c>, ‚Channel |» Proc::Async |» Arrayish‘;
}

{ # 2
    my @a;

    my $c = Channel.new;
    $c.Supply.tap: {
        @a.push: $_
    }

    my $source = Proc::Async.new(‚./t/bin/source‘);
    my $drain = Proc::Async.new(‚./t/bin/drain‘);

    $source |» $drain |» $c;

    is-deeply @a[0,1,2], ("", "Lorem", "adipiscing"), ‚Proc::Async |» Proc::Async |» Channel‘;
}

{ # 3
    my $source = Proc::Async.new(‚./t/bin/source‘);
    my @a;

    my $c = Channel.new;
    $c.Supply.tap: {
        @a.push: $_
    }

    $source |» $c;

    is-deeply @a[0,1,2], ("Lorem", "ipsum", "dolor"), ‚Proc::Async |» Channel‘;
}
