package epikowa.epipure;

import sys.io.File;
import haxe.macro.ExprTools;
import haxe.macro.Expr;
import haxe.macro.Expr.Metadata;
import haxe.macro.ComplexTypeTools;
import haxe.macro.TypeTools;
import haxe.macro.Expr.ComplexType;
import haxe.ds.Either;
#if macro
import eval.luv.Pid;
import epikowa.epipure.EpiPure.EpiPureMacro;
#end
import haxe.macro.Expr.Field;
import haxe.macro.Context;
import haxe.macro.Type;

@:autoBuild(epikowa.epipure.EpiObservable.EpiObservableMacro.build())
interface EpiObservable {}

class EpiObservableController {
	static var frameSignal:Signal<{}> = new Signal();
	static var frameSignalDone:Signal<{}> = new Signal();
}

class ObservableHolder<T> {
	static var globalSignal(default, null):Signal<{}> = new Signal();
	static var globalSignalDone(default, null):Signal<{}> = new Signal();

	public var previousValue:Null<T> = null;
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

	public function new(initialValue:T) {
		this.currentValue = initialValue;
		globalSignal.bind(handleGlobalSignal);
		globalSignalDone.bind(handleGlobalSignalDone);
	}
}

#if macro
class EpiObservableMacro {
	public static var classToHolderType = new Map<String, ComplexType>();
	public static var classToInitializerType = new Map<String, Array<Field>>();

	static function isObservableAlready(targetClass:Ref<ClassType>) {
		do {
			final hasInterface = targetClass?.get().interfaces.filter((i) -> {
				return i.t.toString() == 'epikowa.epipure.EpiObservable';
			}).length > 0;
			if (hasInterface)
				return true;
		} while ((targetClass = targetClass.get().superClass.t) != null);
		return false;
	}

	public static function build() {
		var fields = Context.getBuildFields();
		var currentClass = Context.getLocalClass();
		
		if (currentClass == null)
			return fields;

		final problematicFields = new Array<Field>();
		final newFields = [];
		final removeNames = new Array<String>();
		final observableFields = new Array<Field>();
		final toBeObserved = new Array<Field>();

		for (field in fields) {
			if (field.meta.filter((m) -> m.name == ':skipCheck').length == 0) {
				final result = treatField(field);
				switch (result) {
					case Success(fields, _observableFields):
						for (f in fields) {
							newFields.push(f);
							removeNames.push(f.name);
						}

						for (o in _observableFields) {
							observableFields.push(o);
						}
					case Error:
						// removeNames.push(f.name);
						problematicFields.push(field);
				}
			}
		}
		
		// Prepare initializer
		for (field in fields) {
			if (field.meta.filter((m) -> m.name == ':observable').length > 0) {
				toBeObserved.push(field);
			}
		}
		final copyInit = toBeObserved.copy();
		
		var initializerFields = toBeObserved.map((f) -> {
			var field:Field = {
				name: f.name,
				pos: Context.currentPos(),
				kind: f.kind,
			};

			return field;
		});

		EpiObservableMacro.classToInitializerType.set(currentClass.toString(), initializerFields);
		
		var finalInitializerFields = initializerFields.copy();
		var targetClass = currentClass;
		while ((targetClass = targetClass.get().superClass?.t) != null) {
			final parentInitializer = EpiObservableMacro.classToInitializerType.get(targetClass.toString());
			if (parentInitializer != null) {
				finalInitializerFields = parentInitializer.concat(finalInitializerFields);
			}
		}
		var initializeParam:ComplexType = ComplexType.TAnonymous(finalInitializerFields);

		var myCopy = observableFields.copy();
		if (currentClass.get().superClass != null) {
			final superClassName = currentClass.get().superClass.t.toString();
			final extendType = EpiObservableMacro.classToHolderType.get(superClassName);
			switch (extendType) {
				case TAnonymous(a):
					myCopy = myCopy.concat(a);
				default:
					Context.fatalError('The extended holder type should be TAnonymous', Context.currentPos());
			}
		}

		classToHolderType.set(currentClass.toString(), ComplexType.TAnonymous(myCopy));

			var obsHolderExpr:Expr = {
			pos: Context.currentPos(),
			expr: EObjectDecl(myCopy.map((f) -> {
				return {
					field: f.name,
					expr: macro new epikowa.epipure.EpiObservable.ObservableHolder(null),
					quotes: QuoteStatus.Unquoted
				};
			}))
		};

		var myField:Field = {
			name: '__observables_storage',
			pos: Context.currentPos(),
			kind: FVar(macro :Dynamic, obsHolderExpr), // FVar(ComplexType.TAnonymous(observableFields), expr),
			access: [APublic]
		};

		// var testMacroFunc:Field = {
		// 	name: 'testMacroFunc',
		// 	pos: Context.currentPos(),
		// 	kind: FFun({args: [{name: '_this'}], expr: macro function () {

		// 	}}),
		// 	access: [APublic, AMacro]
		// };

		// fields.push(testMacroFunc);

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

		final superClass = currentClass.get().superClass;
		if (superClass == null || !isObservableAlready(superClass.t)) {
			fields.push(myField);
		}

		//Initializer function
		var initFuncExpr = [for (initField in toBeObserved) {
			final fieldName = initField.name;
			macro __observables_storage.$fieldName.currentValue = init.$fieldName;
		}];
		// var initializerFuncExpr = macro __observables_storage = ${initExpr};
		var initializerFuncField:FieldType = FFun({
			args: [{name: 'init', type: macro: Dynamic}],
			expr: macro {this.__observables_storage = $obsHolderExpr; $b{initFuncExpr}},
			ret: macro :Void
		});
		fields.push({
			name: '__observables_initializer',
			pos: Context.currentPos(),
			kind: initializerFuncField,
			access: superClass == null ? [] : [AOverride]
		});

		//Constructor
		var initExpr = [for (initField in toBeObserved) {
			final fieldName = initField.name;
			macro __observables_storage.$fieldName.currentValue = init.$fieldName;
		}];

		final finalInitExpr = currentClass.get().superClass != null ? macro {super(init); $b{initExpr}} : macro {this.__observables_initializer(init);};

		var myPseudoConstructor = FFun({
			args: [
				{
					name: "init",
					type: initializeParam,
				}
			],
			expr: finalInitExpr
		});

		fields.push({
			name: 'new', // "abc" + Math.round(Math.random() * 98555),
			kind: myPseudoConstructor,
			pos: Context.currentPos(),
			access: [APublic],
		});

		// fields.push(storage);
		for (field in newFields) {
			fields.push(field);
		}

		// var t = macro :String;

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
			if (value == __observables_storage.$name.currentValue)
				return value;

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
			meta: [
				// {
				// 	pos: Context.currentPos(),
				// 	params: [],
				// 	name: ':isVar'
				// }
			]
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

class EpiObservableTools {
	public macro static function getObservable(e:ExprOf<EpiObservable>) {
		final t = Context.typeof(e);
		final c = TypeTools.getClass(t);

		final targetType = EpiObservableMacro.classToHolderType.get(TypeTools.toString(t));
		final toReturn = macro $e.__observables_storage;
		return generateTypePromotion(toReturn, targetType);
	}

	#if macro
	static function generateTypePromotion(expr:Expr, toType:ComplexType) {
		var def = ExprDef.ECheckType(expr, toType);
		return {
			expr: def,
			pos: Context.currentPos()
		};
	}
	#end
}

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
