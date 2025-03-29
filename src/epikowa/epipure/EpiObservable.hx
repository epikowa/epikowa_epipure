package epikowa.epipure;

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

#if macro
class EpiObservableMacro {
    public static function build() {
        trace('Running EpiObservableMacro');
        var fields = Context.getBuildFields();
        final problematicFields = new Array<Field>();
        final newFields = [];
        final removeNames = new Array<String>();

        for (field in fields) {
            final result = treatField(field);
            switch (result) {
                case Success(fields):
                    for(f in fields) {
                        newFields.push(f);
                        removeNames.push(f.name);
                    }
                case Error:
                    // removeNames.push(f.name);
                    problematicFields.push(field);

            }
        }

        var storage:Field = {
            name: '__observables_storage',
            pos: Context.currentPos(),
            kind: FVar(macro :Map<String, {currentValue: Any, lastValue: Any}>, {
                expr: (macro new Map()).expr,
                pos: Context.currentPos()
            }),
            access: [APublic],
        };

        fields = fields.filter((f) -> {
            return removeNames.indexOf(f.name) < 0;
        });

        fields.push(storage);
        for (field in newFields) {
            fields.push(field);
        }

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
                    return Success(generateField(field));
                } else {
                    Context.warning('Field ${field.name} must be marked with \'@:observable\'', field.pos);

                    return Error;
                }


            case FProp(get, set, t, e):
                Context.warning('Field ${field.name}: properties are not supported yet', field.pos);
                return Error;
            case FFun(f):
                return Success([]);
        }
        return Error;
    }

    static function generateField(field:Field) {
        var name = field.name;

        var setter = macro {
            this.$name = value;
            if (!__observables_storage.exists($v{name})) {
                __observables_storage.set($v{name}, {
                    currentValue: null,
                    lastValue: null
                });
            }
            var e = __observables_storage.get($v{name});
            e.lastValue = e.currentValue;
            e.currentValue = value;
            return value;
        };


        var getter = macro {
            return this.$name;
        };

        var s:Field = {
            name: 'set_${name}',
            pos: Context.currentPos(),
            kind: FFun({
                args: [{name: 'value', type: macro :String}],
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
            kind: FProp('get', 'set', macro :String, macro 'plopinette'),
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
    Success(fields:Array<Field>);
    Error;
}
#end