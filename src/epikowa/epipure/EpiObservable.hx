package epikowa.epipure;

import haxe.macro.Expr;
import haxe.macro.Expr.Metadata;
import haxe.macro.ComplexTypeTools;
import haxe.macro.TypeTools;
import haxe.macro.Expr.ComplexType;
import haxe.ds.Either;
#if macro
import epikowa.epipure.EpiPure.EpiPureMacro;
#end
import haxe.macro.Expr.Field;
import haxe.macro.Context;
import haxe.macro.Type;

@:autoBuild(epikowa.epipure.EpiObservable.EpiObservableMacro.build())
interface EpiObservable {
}

class EpiObservableController {
    static var frameSignal:Signal<Void> = new Signal();
    static var frameSignalDone:Signal<Void> = new Signal();
}

class ObservableHolder<T> {
    static var globalSignal(default, null):Signal<Void> = new Signal();
    static var globalSignalDone(default, null):Signal<Void> = new Signal();

    public var previousValue:Null<T>;
    public var currentValue:T;
    public var signal(default, null):Signal<T> = new Signal();
    public var frameSignal(default, null):Signal<T> = new Signal();
    public var isDirty:Bool = false;
    
    function handleGlobalSignal(_) {
        frameSignal.emit(currentValue);
        this.isDirty = false;
    }

    function handleGlobalSignalDone(_) {
        isDirty = false;
    }

    public function new() {
        globalSignal.bind(handleGlobalSignal);
        globalSignalDone.bind(handleGlobalSignalDone);
    }
}

#if macro
class EpiObservableMacro {
    public static function build() {
        trace('Running EpiObservableMacro');
        var fields = Context.getBuildFields();
        var currentClass = Context.getLocalClass();

        final problematicFields = new Array<Field>();
        final newFields = [];
        final removeNames = new Array<String>();
        final observableFields = new Array<Field>();

        for (field in fields) {
            final result = treatField(field);
            switch (result) {
                case Success(fields, _observableFields):
                    for(f in fields) {
                        newFields.push(f);
                        removeNames.push(f.name);
                    }

                    for (o in _observableFields) {
                        trace('badam', o.name);
                        observableFields.push(o);
                    }
                case Error:
                    // removeNames.push(f.name);
                    problematicFields.push(field);

            }
        }

        var expr:Expr = {
            pos: Context.currentPos(),
            expr:EObjectDecl(fields.map((f) -> {
                return {
                    field: f.name,
                    expr: macro new epikowa.epipure.EpiObservable.ObservableHolder(),
                    quotes: QuoteStatus.Unquoted
                };
            }))
        };

        var myField:Field = {
            name: '__observables_storage',
            pos: Context.currentPos(),
            kind: FVar(ComplexType.TAnonymous(observableFields), expr),
            access: [APublic]
        };

        
        // var storage:Field = {
        //     name: '__observables_storage',
        //     pos: Context.currentPos(),
        //     kind: FVar(macro :Map<String, {currentValue: Any, lastValue: Any}>, {
        //         expr: (macro new Map()).expr,
        //         pos: Context.currentPos()
        //     }),
        //     access: [APublic],
        // };
        
        fields = fields.filter((f) -> {
            return removeNames.indexOf(f.name) < 0;
        });
        
        var hasInterface = currentClass?.get().superClass?.t.get().interfaces.filter((i) -> {
            return i.t.toString() == 'epikowa.epipure.EpiObservable';
        }).length > 0;

        if (!hasInterface) {
            fields.push(myField);
        }
        // fields.push(storage);
        for (field in newFields) {
            fields.push(field);
        }

        var t = macro :String;

        // fields.push({
        //     name: "plop",
        //     pos: Context.currentPos(),
        //     kind: FVar(macro :epikowa.epipure.EpiObservable.ObservableHolder<$t>, macro new epikowa.epipure.EpiObservable.ObservableHolder()),
        //     access: [APublic]
        // });

        return fields;
    }

    static function treatField(field:Field):TreatmentResult {
        switch (field.kind) {
            case FVar(t, e):
                if (!EpiPureMacro.isComplexTypeImmutable(Left(t)) || isComplexTypeObservable(Left(t))) {
                    Context.warning('Field ${field.name} must be Immutable or Observable', field.pos);

                    return Error;
                }

                if (field.meta.filter((m) -> m.name == ':observable').length > 0) {
                    var observableField:Field = {
                        name: field.name,
                        pos: Context.currentPos(),
                        kind: FVar(macro :epikowa.epipure.EpiObservable.ObservableHolder<$t>),
                        access: [APublic]
                    };
                    return Success(generateField(field, t, e), [observableField]);
                } else {
                    Context.warning('Field ${field.name} must be marked with \'@:observable\'', field.pos);

                    return Error;
                }


            case FProp(get, set, t, e):
                Context.warning('Field ${field.name}: properties are not supported yet', field.pos);
                return Error;
            case FFun(f):
                return Success([], []);
        }
        return Error;
    }

    static function generateField(field:Field, t:Null<ComplexType>, e:Null<Expr>) {
        var name = field.name;

        var setter = macro {
            if (value == __observables_storage.$name.currentValue) return value;

            __observables_storage.$name.previousValue = __observables_storage.$name.currentValue;

            __observables_storage.$name.currentValue = value;
            
            __observables_storage.$name.signal.emit(value);

            __observables_storage.$name.isDirty = true;
            
            return value;
        };


        var getter = macro {
            return __observables_storage.$name.currentValue;
        };

        var s:Field = {
            name: 'set_${name}',
            pos: Context.currentPos(),
            kind: FFun({
                args: [{name: 'value', type: t}],
                expr: setter
            }),
            access: [APrivate]
        };

        var g:Field = {
            name: 'get_${name}',
            pos: Context.currentPos(),
            kind: FFun({
                args: [],
                expr: getter
            }),
            access: [APrivate]
        };

        var f:Field = {
            name: name,
            pos: Context.currentPos(),
            kind: FProp('get', 'set', t, e),
            access: [APublic],
            meta: [{
                pos: Context.currentPos(),
                params: [],
                name: ':isVar'
            }]
        };

        return [s, g, f];
    }

    static function isComplexTypeObservable(t:Either<ComplexType, Type>):Bool {
        var ty = switch (t) {
            case Left(v):
                ComplexTypeTools.toType(v);
            case Right(v):
                v;
        };

        switch (ty) {
            case TInst(t, params):
                for (int in t.get().interfaces) {
                    if (int.t.toString() == 'epikowa.epipure.EpiObservable') {
                        return true;
                    }
                }
            default:
        }

        return false;
    }
}

enum TreatmentResult {
    Success(fields:Array<Field>, observableFields:Array<Field>);
    Error;
}
#end

class Signal<T> {
    private var listeners:Array<T->Void>;
    
    public function new() {
        listeners = [];
    }

    public function bind(listener:T->Void) {
        listeners.push(listener);
    }

    public function emit(value:T) {
        for (listener in listeners) {
            listener(value);
        }
    }

    public function hasListeners():Bool {
        return listeners.length > 0;
    }

    public function unsubscribe(listener:T->Void):Void {
        listeners = listeners.filter((l) -> {
            return !Reflect.compareMethods(l, listener);
        });
    }
}