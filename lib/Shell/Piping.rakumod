use v6.d;

subset Arrayish of Any where { !.isa('Code') && .^can(‚push‘) && .^can(‚list‘) }

role Exception::Refinable is Exception is export {
    multi method refine(::?CLASS:U: &conditional, &message) {
        self.WHO::<@refinements>.push: &conditional, &message;
    }
    multi method refine(::?CLASS:U: :$revert-all!) {
        self.WHO::<@refinements>.splice(0, *);
    }
    multi method refine(::?CLASS:U: &to-remove, :$revert!) {
        for self.WHO::<@refinements>.kv -> $idx, &c {
            if &c === &to-remove {
                self.WHO::<@refinements>.splice($idx, 2);
                last;
            }
        }
    }
    method refinements {
        self.WHO::<@refinements>
    }
}

class X::Shell::PipeeStartFailed is export {
    has $.cmd;
    has $.env-path;
}

class X::Shell::CommandNotFound does Exception::Refinable is export {
    our @refinements;
    has $.cmd;
    has $.path;
    method message {
        for @refinements -> &cond, &message {
            if cond(self) {
                return message(self);
            }
        }
        $.path 
            ?? „The shell command ⟨$.cmd⟩ was not found in ⟨$.path⟩.“
            !! „The shell command ⟨$.cmd⟩ was not found.“
    }
}
class X::Shell::CommandNoAccess is Exception::Refinable is export {
    our @refinements;
    has $.cmd;
    method message { 'The shell command ⟨' ~ $.cmd ~ '⟩ is not accessible.' }
}

class X::Shell::NonZeroExitcode is Exception is export {
    has $.pipe;
    method message {
        my @failers = $.pipe.exitcodes.grep(*.exitcode != 0);
        'Pipe terminated with non-zero exitcode.' ~ „\n“ ~ (@failers».command Z~ „:\n“ xx * Z~ @failers».Str».indent(2)).join(„\n“)
    }
}

class X::Shell::NoExitcodeYet is Exception is export {
    has $.pipe;
    method message {
        ‚Pipe did not produce exitcode yet.‘
    }
}

class Shell::Pipe::Exitcode::Container is export {
    has &.callback;
}

class Shell::Pipe::Path::Container {
    has @.path;
}

class Shell::Pipe is export {
    class Command { }

    class Switch {
        has $.name;
        method gist { $.name }
        method Str { die('invalid coersion') }
    }
    
    constant on is export := Shell::Pipe::Switch.new: :name<on>;
    constant off is export := Shell::Pipe::Switch.new: :name<off>;

    class BlockContainer {
        has &.code;
        has $.proc-in is rw;
        has $.file-in is rw;
        has $.proc-out;
        has $.proc-out-stdout;
        method start { 
            with $.proc-in {
                start { 
                    await $.proc-out.ready;
                    await $.proc-in.ready with $.proc-in;
                    for $.proc-out-stdout.lines {
                        my $value := &.code.($_);
                        my $processed = $value === Nil ?? ‚‘ !! $value ~ "\n";
                        await $.proc-in.write: $processed.encode with $.proc-in;
                      # ^^^^^ WORKAROUND for #R3817
                    }
                    $.proc-in.close-stdin with $.proc-in;
                }
            } else {
                with $.file-in {
                    start {
                        for $.proc-out-stdout.lines {
                            my $value := &.code.($_);
                            my $processed = $value === Nil ?? ‚‘ !! $value ~ "\n";
                            $.file-in.write: $processed.encode;
                        }
                    }
                } else {
                    start { 
                        await $.proc-out.ready;
                        for $.proc-out-stdout.lines {
                            my $value := &.code.($_);
                            my $processed = $value === Nil ?? ‚‘ !! $value ~ "\n";
                        }
                        $.proc-in.close-stdin with $.proc-in;
                    }
                }
            }
        }
    }

    class Exitcode {
        has $.exitcode;
        has $.command;
        has @.STDERR;

        multi method ACCEPTS(::?CLASS:D: Numeric $rhs) {
            $!exitcode ~~ $rhs
        }
        multi method ACCEPTS(::?CLASS:D: Str $rhs) {
            $!command ~~ $rhs
        }
        multi method ACCEPTS(::?CLASS:D: Regex $rhs) {
            @!STDERR.join(„\n“) ~~ $rhs
        }
        method Bool {
            $!exitcode != 0
        }
        method Str {
            @.STDERR || „<exitcode $.exitcode>“
        }
    }

    has @.pipees;
    has @.starters; # list of Callable returning Awaitable

    has $.name is rw = "Shell::Pipe <anon>";
    has $.search-path is rw;
    has &.done is rw = Code;
    has @.exitcodes;
    has $.stderr is rw = Whatever;
    has $.failure;
    has @.captured-stderr;
    has Bool $.quiet is rw; # divert STDERR away from terminal

    method start {
        my $*capture-stderr = CALLERS::<$*capture-stderr> // off;
        my $*quiet = CALLERS::<$*quiet> // off;
        if $.stderr !~~ Whatever || $*capture-stderr ~~ on {
            for @.pipees.kv -> $index, $proc {
                if $proc ~~ Proc::Async {
                    if $.stderr ~~ Code {
                        try $proc.stderr.lines.tap: -> $line { $.stderr.($index, $line) };
                    } elsif $.stderr ~~ Channel {
                        try $proc.stderr.lines.tap: -> $line { $.stderr.send( ($index, $line) ) };
                    } elsif $.stderr ~~ Capture or $*capture-stderr ~~ on {
                        try $proc.stderr.lines.tap: -> $line { $.captured-stderr.push: ($index, $line) };
                    } elsif $.stderr ~~ IO::Handle {
                        try $proc.stderr.lines.tap: -> $line { 
                            $.stderr.put: now.DateTime.Str, ' ', $index, ' ', $line;
                        };
                    } elsif $.stderr ~~ IO::Path {
                        $.stderr = open $.stderr, :w;
                        try $proc.stderr.lines.tap: -> $line { 
                            $.stderr.put: now.DateTime.Str, ' ', $index, ' ', $line;
                        };
                    } elsif $.stderr ~~ Arrayish {
                        try $proc.stderr.lines.tap: -> $line { $.stderr.push: ($index, $line) };
                    }

                }
            }
        } elsif $.quiet || $*quiet ~~ on {
            for @.pipees -> $proc {
                if $proc ~~ Proc::Async {
                    try $proc.stderr.tap: -> $s {};
                }
            }
        }
        # FIXME check if any Promise was broken, because a process did not start
        my @proms = await(do for @.starters.reverse -> &c { |c });
        for @proms.reverse.kv -> $idx, $v {
            when $v ~~ Proc {
                my $STDERR := @.captured-stderr.map({ .head == $idx ?? .tail !! Empty }).join(„\n“) if $.stderr ~~ Capture;
                @!exitcodes[$idx] = Exitcode.new(:exitcode($v.exitcode), :command($v.command.head), :$STDERR);
            }
            default {
                @!exitcodes[$idx] = Exitcode.new(:exitcode(0), :command(@!pipees[$idx].&gist-of-pipee));
            }
        }

        $!failure = Failure.new(X::Shell::NonZeroExitcode.new(:pipe(self))) if @!exitcodes».Bool.any;

        &.done.(self) with &.done;
        fail($!failure) if $!failure ~~ Failure && !$!failure.handled;
        Nil
    }

    method sink { 
        self.start;
        $!failure ~~ Failure && !$!failure.handled ?? $!failure.throw !! Nil
    }

    method gist { 
        @.pipees.map(*.&gist-of-pipee).join(' ↦ ')
    }
    sub gist-of-pipee($e) {
        given $e { 
            when Proc::Async { .path.IO.basename }
            when Routine { .name }
            when Block { „Block({.file.IO.basename}:{.line})“ }
            when BlockContainer { „Block({.code.file.IO.basename}:{.code.line})“ }
            when Arrayish { .?name // .WHAT.gist }
        }
    }
    method exitcodes {
        $!failure.handled = True if $!failure ~~ Failure;
        fail(X::Shell::NoExitcodeYet.new(:pipe(self))) unless @!exitcodes.elems;
        my $bool = @!exitcodes».Bool.any.so;
        @!exitcodes but $bool
    }
}

INIT {
    # use MONKEY-TYPING;

    # augment class Regex {
    #     multi method ACCEPTS(Regex:D: Shell::Pipe::Exitcode:D $ex) {
    #         CALLER::<$/>:exists ?? (CALLER::<$/> := $/) !! (CALLER::CALLER::<$/> := $/);

    #         ?$ex.STDERR.join(„\n“).match(self)
    #     }
    # }


    # augment class Int {
    #     multi method ACCEPTS(Int:D: Shell::Pipe::Exitcode:D $ex) {
    #         self.ACCEPTS($ex.exitcode)
    #     }
    # }


    # augment class Str {
    #     multi method ACCEPTS(Str:D: Shell::Pipe::Exitcode:D $ex) {
    #         self.ACCEPTS($ex.command)
    #     }
    # }

    Regex.^add_multi_method(‚ACCEPTS‘, my method (Regex:D: Shell::Pipe::Exitcode:D $ex) { 
        (CALLER::<$/>:exists) ?? (CALLER::<$/> := $/) !! 
            (CALLER::CALLER::<$/>:exists) ?? (CALLER::CALLER::<$/> := $/) !! 
                (CALLER::CALLER::CALLER::<$/> := $/);

        ?$ex.STDERR.join(„\n“).match(self)
    });
    Int.^add_multi_method(‚ACCEPTS‘, my method (Int:D: Shell::Pipe::Exitcode:D $ex) { self.ACCEPTS($ex.exitcode) });
    Str.^add_multi_method(‚ACCEPTS‘, my method (Str:D: Shell::Pipe::Exitcode:D $ex) { self.ACCEPTS($ex.command) });
    Int.^compose;
    Regex.^compose;
    Str.^compose;

}

constant px is export = Shell::Pipe::Command.new;

multi PX($ ($command, *@args)) {
    sub whereis {
        %*ENV<PATH>.split(‚:‘).map(*.IO.add($command));
    }

    my $in-path = not $command.contains($*SPEC.dir-sep);
    my $command-path = $in-path ?? whereis.first(*.x) !! $command.IO;

    X::Shell::CommandNotFound.new(:cmd($command), :path($in-path ?? %*ENV<PATH> !! Nil)).throw if !$command-path.?IO.e;
    X::Shell::CommandNoAccess.new(:cmd($command-path)).throw if !$command-path.?IO.x;

    Proc::Async.new: $command-path, |@args
}

multi postcircumfix:<{ }>(px, $arg) is export {
    PX $arg.list
}

multi postcircumfix:<{ }>(px, @args) is export {
    PX @args
}

multi infix:<|»>(Proc::Async:D $out, Proc::Async:D $in, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export { 
    # TEST DONE
    my $pipe = Shell::Pipe.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.append: $out, $in;
    $pipe.starters.append: -> {
        $in.start, $out.start 
    }

    $in.bind-stdin: $out.stdout;

    $pipe
}

multi infix:<|»>(Shell::Pipe:D $pipe where $pipe.pipees.tail ~~ Shell::Pipe::BlockContainer, Proc::Async:D $in, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export {
    # TEST DONE
    my $blockish = $pipe.pipees.tail;

    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    # FIXME workaround R#3778
    $in.^attributes.grep(*.name eq '$!w')[0].set_value($in, True);
    $blockish.proc-in = $in;

    $pipe.pipees.push: $in;
    $pipe.starters.append: -> {
        $in.start
    }

    $pipe
}

multi infix:<|»>(Shell::Pipe:D $pipe, Proc::Async:D $in, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export { 
    # TEST DONE
    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    my $out = $pipe.pipees.tail;
    $pipe.pipees.push: $in;

    given $out {
        when Proc::Async { 
            $in.bind-stdin: .stdout;
            $pipe.starters.push: -> { $in.start };
        }
        when Arrayish { 
            fail "Arrayish not at the tail or head of a pipe.";
        }
    }

    $pipe
}

multi infix:<|»>(Proc::Async:D $out, Arrayish:D \a, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export { 
    # TEST DONE
    my $pipe = Shell::Pipe.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: $out;
    $pipe.pipees.push: a;

    $out.stdout.lines.tap(-> \e { a.push: e });
    $pipe.starters.push(-> { $out.start });

    $pipe
}

multi infix:<|»>(Shell::Pipe:D $pipe where $pipe.pipees.tail ~~ Proc::Async, Arrayish:D \a, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export { 
    # TEST DONE
    my $out = $pipe.pipees.tail;
    $pipe.pipees.push: a;

    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    $out.stdout.lines.tap(-> \e { a.push: e });

    $pipe
}

multi infix:<|»>(Shell::Pipe:D $pipe where $pipe.pipees.tail ~~ Shell::Pipe::BlockContainer, Arrayish:D \a, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export {
    # TEST DONE
    my $cont = $pipe.pipees.tail;
    my $fake-proc = class { 
        method write($blob) { my $p = Promise.new; $p.keep; a.push: $blob.decode.chomp; $p } 
                              # ^^^^^^^^^^^^^^^^^^^^ WORKAROUND for R#3817
        method ready { my $p = Promise.new; $p.keep; $p }
        method close-stdin { True }
    }.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    $cont.proc-in = $fake-proc;
    $pipe.pipees.push: a;

    $pipe
}

multi infix:<|»>(Arrayish:D \a, Proc::Async:D $in, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export { 
    # TEST DONE
    my $pipe = Shell::Pipe.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: a;
    $pipe.pipees.push: $in;
    # FIXME workaround R#3778
    $in.^attributes.grep(*.name eq '$!w')[0].set_value($in, True);
    $pipe.starters.push: -> { $in.start };
    $pipe.starters.push: -> { 
        start {
            LEAVE try $in.close-stdin;
            await $in.ready;
            await $in.write: „$_\n“.encode for a.list;
        }
    }

    $pipe
}

multi infix:<|»>(&c, Proc::Async:D $in, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export {
    # TEST DONE
    my $pipe = Shell::Pipe.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: &c;
    $pipe.pipees.push: $in;
    # FIXME workaround R#3778
    $in.^attributes.grep(*.name eq '$!w')[0].set_value($in, True);

    $pipe.starters.push: -> {
        | $in.start, start {
            LEAVE try $in.close-stdin;
            await $in.ready;
            for c() {
                next if $_ === Nil;
                await $in.write: „$_\n“.encode;
            }
        }
    }
    
    $pipe
}

multi infix:<|»>(Shell::Pipe:D $pipe, &c, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export {
    # TEST DONE
    my $out = $pipe.pipees.tail;
    my $cont = Shell::Pipe::BlockContainer.new: :code(&c), :proc-out($$out), :proc-out-stdout($out.stdout);

    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: $out;
    $pipe.pipees.push: $cont;
    # $out.stdout.lines.tap(&c);

    $pipe.starters.push: -> { $cont.start };

    $pipe
}

multi infix:<|»>(Proc::Async:D $out, &c, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) { 
    # TEST DONE
    my $pipe = Shell::Pipe.new;
    my $cont = Shell::Pipe::BlockContainer.new: :code(&c), :proc-out($out), :proc-out-stdout($out.stdout);

    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: $out;
    $pipe.pipees.push: $cont;

    $pipe.starters.push: -> { $out.start; }
    $pipe.starters.push: -> { $cont.start; };

    $pipe;
}


multi infix:<|»>(Supply:D \s, Proc::Async:D $in, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export {
    # TEST DONE
    my $pipe = Shell::Pipe.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: s;
    $pipe.pipees.push: $in;
    # FIXME workaround R#3778
    $in.^attributes.grep(*.name eq '$!w')[0].set_value($in, True);

    $pipe.starters.push: -> { start {
        await $in.ready;
        s.tap: -> $v { await $in.write: „$v\n“.encode }, :done({ try $in.close-stdin }), :quit({ try $in.close-stdin });
    } };
    $pipe.starters.push: -> { $in.start };

    $pipe
}

multi infix:<|»>(Proc::Async:D $out, Supplier:D \s, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export {
    # TEST DONE
    my $pipe = Shell::Pipe.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: $out;
    $pipe.pipees.push: s;
    $pipe.starters.push: -> { $out.start };
    $out.stdout.lines.tap(-> $v { 
        s.emit($v);
    });

    $pipe
}

multi infix:<|»>(Shell::Pipe:D $pipe where $pipe.pipees.tail ~~ Proc::Async, Supplier:D \s, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export {
    # TEST DONE
    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    my $out = $pipe.pipees.tail;
    $pipe.pipees.push: s;
    $out.stdout.lines.tap(-> $v { 
        s.emit($v);
    });

    $pipe
}

multi infix:<|»>(Channel:D \c, Proc::Async:D $in, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export {
    # TEST DONE
    my $pipe = Shell::Pipe.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: c;
    $pipe.pipees.push: $in;
    # FIXME workaround R#3778
    $in.^attributes.grep(*.name eq '$!w')[0].set_value($in, True);

    $pipe.starters.push: -> { start {
        for c.list -> $v {
            await $in.write: „$v\n“.encode;
        }
        $in.close-stdin;
    } };
    $pipe.starters.push: -> { $in.start };

    $pipe
}

multi infix:<|»>(Proc::Async $out, Channel:D \c, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export {
    # TEST DONE
    my $pipe = Shell::Pipe.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: $out;
    $pipe.pipees.push: c;

    $out.stdout.lines.tap: -> $v { c.send: $v };
    $pipe.starters.push: -> { $out.start };

    $pipe
}

multi infix:<|»>(Shell::Pipe:D $pipe where $pipe.pipees.tail ~~ Proc::Async, Channel:D \c, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export {
    # TEST DONE
    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    my $out = $pipe.pipees.tail;
    
    $pipe.pipees.push: c;
    $out.stdout.lines.tap(-> $v {
        c.send: $v
    });

    $pipe
}
multi infix:<|»>(IO::Handle:D $file, Proc::Async $proc, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export {
    # TEST DONE
    my $pipe = Shell::Pipe.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: $file;
    $pipe.pipees.push: $proc;

    $proc.bind-stdin: $file;

    $pipe.starters.push: -> { $proc.start }

    $pipe
}

multi infix:<|»>(IO::Path:D $path, Proc::Async $proc, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export {
    my $pipe = $path.open() |» $proc :&done :$stderr :$quiet;
}

multi infix:<|»>(Shell::Pipe:D $pipe where $pipe.pipees.tail ~~ Proc::Async, IO::Handle:D $file, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export {
    my $out = $pipe.pipees.tail;

    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: $file;
    $out.bind-stdout: $file;

    $pipe
}

multi infix:<|»>(Shell::Pipe:D $pipe where $pipe.pipees.tail ~~ Proc::Async, IO::Path:D $path, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export {
    $pipe |» $path.open(:w) :&done :$stderr :$quiet
}

multi infix:<|»>(Shell::Pipe:D $pipe where $pipe.pipees.tail ~~ Shell::Pipe::BlockContainer, IO::Handle:D $file, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export {
    # TEST DONE
    my $out = $pipe.pipees.tail;
    $pipe.done = &done;
    $pipe.stderr = $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: $file;

    $out.file-in = $file;

    $pipe
}

multi infix:<|»>(Shell::Pipe:D $pipe where $pipe.pipees.tail ~~ Shell::Pipe::BlockContainer, IO::Path:D $path, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export {
    $pipe |» $path.open(:w)
}

sub infix:«|>>»(\a, \b, :&done? = Code, :$stderr? = Whatever, Bool :$quiet?) is export { a |» b :&done :$stderr :$quiet }
