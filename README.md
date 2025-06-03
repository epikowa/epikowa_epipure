# Introduction
This library helps you create immutable classes by letting you know if your class really is immutable and if it only uses immutable classes itself.

# How to use
When you want a class to be immutable, it should implement `epikowa.epipure.EpiPure`.

```haxe
class ImmutableCounter implements epikowa.epipure.EpiPure {
    public final i:Int;

    public function new(i:Int) {
        this.i = i;
    }

    public function increment() {
        return new ImmutableCounter(i+1);
    }
}

class Main {
    public static function main() {
        var myCounter = new ImmutableCounter(0);
        trace('First step: ${myCounter.i}'); // First step: 0
        myCounter = myCounter.increment();
        trace('Second step: ${myCounter.i}'); // Second step: 1
    }
}
```

If your class does not meet conditions to be immutable, you will get errors and warnings at compile time.

# What is allowed / disallowed
Your class has to follow some rules to be immutable.
## Functions
All functions are allowed.
## Properties
Properties are allowed only if they are of a type that is considered immutable and have their setter set to `never`.

All getters are allowed.

```haxe
class ImmutableExample implements epikowa.epipure.EpiPure {
    var s(get, null):String; // Not allowed
    var t(get, never):String; // Allowed
}
```

## Variables
Variable fields only are accepted if they are final.

```haxe
class ImmutableExample implements epikowa.epipure.EpiPure {
    var s:String; // Not allowed
    final t:String; // Allowed
}
```

## Types
Types referenced by a variables have to themselves be immutable.  
Immutable types are : `Int`, `Float`, `String`, all classes implementing `epikowa.epipure.EpiPure` and all classes marked with `@:immutable`. `Null<T>` also is considered immutable if `T` is immutable.

For any other generic class, type parameters are not checked.

# Using EpiObservable
`EpiObservable`s' fields can be observed for changes.  
In order to allow that, they can only contain `EpiPure` or immutable types.  

> [!WARNING]
> At the moment, custom constructors are not supported.  
> They should be soon.  
