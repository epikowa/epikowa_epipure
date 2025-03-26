import epikowa.epipure.EpiPure;

class Main {
    public static function main() {
        var myCounter = new ImmutableCounter(0);
        trace('First step: ${myCounter.i}');
        myCounter = myCounter.increment();
        trace('Second step: ${myCounter.i}');
    }
}

class Plop {
    var s(default, never):String;

    public function new() {
        new TestClass(12);
    }
}

class TestClass implements EpiPure {
    var name(default, never):Person;
    var i(default, never):Int;
    final s:Null<Person>;

    public function new(i:Int) {
        s = null;
    }
}

class Person implements EpiPure {
    var name(default, never):String;
}

class ImmutableCounter implements epikowa.epipure.EpiPure {
    public final i:Int;

    public function new(i:Int) {
        this.i = i;
    }

    public function increment() {
        return new ImmutableCounter(i+1);
    }

    @:to public function toString() {
        return Std.string(i);
    }
}
