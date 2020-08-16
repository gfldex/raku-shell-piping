use v6.d;

class Switch {
    has $.name;
    method gist { $.name }
    method Str { die('invalid coersion') }
    method Bool { die('invalid coersion') }
}

constant on is export := Switch.new: :name<on>;
constant off is export := Switch.new: :name<off>;
