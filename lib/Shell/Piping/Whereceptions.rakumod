use v6.d;

use Shell::Piping::Switch;

INIT my $env-color = %*ENV<SHELLPIPINGNOCOLOR>:!exists;

sub RED($str, :$color) { 
    $*ERR.t && $color ?? „\e[31m$str\e[0m“ !! $str
}

class X::Whereception is Exception is export {
    has $.stale-symlink is rw;
    has $.is-colored = False;
    method is-dangling-symlink {
        $.stale-symlink = do with $.path { .IO.l & !.IO.e };
    }
}

class X::IO::FileNotFound is X::Whereception is export {
    has $.path;
    method message {
        RED $.is-dangling-symlink ?? „The file ⟨$.path⟩ is a dangling symlink.“ !! „The file ⟨$.path⟩ was not found.“, :color($.is-colored)
    }
}

class X::IO::DirectoryNotFound is X::Whereception is export {
    has $.path;
    method message {
        RED $.is-dangling-symlink ?? „The directory ⟨$.path⟩ is a dangling symlink.“ !! „The directory ⟨$.path⟩ was not found.“, :color($.is-colored)
    }
}
class X::IO::FileNotExecutable is X::Whereception is export {
    has $.path;
    method message {
        RED $.is-dangling-symlink ?? „The executable ⟨$.path⟩ is a dangling symlink.“ !! „The file ⟨$.path⟩ is not executable.“, :color($.is-colored)
    }
}

our &it-is-a-file = -> IO() $_ {
    my $is-colored = ($*colored-exceptions // on) ~~ on && $env-color;
    # if it exists not a file nor a dir, it must be a device/fifo/etc so we take it
    (.e && .f) || ( .e && !.f && !.d ) || fail (X::IO::FileNotFound.new(:path(.Str), :$is-colored))
}

our &it-is-a-directory = -> IO() $_ {
    my $is-colored = ($*colored-exceptions // on ~~ on) && $env-color;
    .d || fail (X::IO::DirectoryNotFound.new(:path(.Str), :$is-colored))
}

our &it-is-executable = -> IO() $_ {
    my $is-colored = ($*colored-exceptions // on ~~ on) && $env-color;
    .x || fail (X::IO::FileNotExecutable.new(:path(.Str), :$is-colored))
}


sub EXPORT {
    %(
        'on' => on,
        'off' => off
    )
}
