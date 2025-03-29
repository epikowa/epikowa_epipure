package epikowa.epipure.tests;

class TestEpiPure {
    static var t:Null<String>;

    public static function main() {
        trace('Coucou');

        var table = new ImmutableArray<Int>([]);
        table = table.append(12);
        trace(table);
        table = table.append(14);

        for (element in table) {
            trace(element);
        }

        var t = new Test<String>([]);
        t = t.append('plop');
        for (a in t) {
            trace(a);
        }
    }
}

@:nullSafety(Strict)
class Plop implements EpiPure {
    final s:ImmutableArray<String>;
    final t:Test<String> = new Test([]);

    public function new() {
        s = new ImmutableArray<String>([]);
    }
}

@:nullSafety(Strict)
@:forward.new
@:forward(append, prepend, iterator)
abstract Test<T>(ImmutableArray<T>) {
    @:from
    static function fromImmutableArray<T>(value:ImmutableArray<T>) {
        return new Test<T>(value.toArray());
    }

    @:arrayAccess
    public inline function get(key:Int):Null<T> {
        return this.get(key);
    }
}