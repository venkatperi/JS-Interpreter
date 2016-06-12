_ = require 'lodash'
Interpreter = require './interpreter'
DefaultDelegate = require './DefaultDelegate'

# convert a value to pseudo values (for use inside the sandbox)
Interpreter::fromNative = ( value, noRecurse ) ->
  #console.log "fromNative: #{value}"
  return value if value?.type is 'function'
  if typeof value is "function"
    return @wrapNativeFn value

  if !value or !_.isObjectLike(value)
    #if typeof value != "object" or value == null
    return @createPrimitive value

  if Array.isArray value
    pseudoArray = @createObject @ARRAY
    for item, i in value
      @setProperty pseudoArray, i, @fromNative item

    return pseudoArray

  #console.log value
  pseudoObject = @createObject @OBJECT
  for key, val of value
    @setProperty pseudoObject, key, @fromNative val

  return pseudoObject

# convert pseudo objects from the sandbox into real objects
Interpreter::toNative = ( value ) ->
  return value.data if value.isPrimitive

  return value if value.type == "function"

  if value.length? # array
    newArray = []
    for i in [ 0...value.length ]
      newArray.push @toNative value.properties[ i ]

    return newArray

  newObject = {}
  for key, val of value.properties
    newObject[ key ] = @toNative val

  return newObject

# convert a list of arguments from pseudo to native (see toNative)
Interpreter::convertArgsToNative = ( args... ) ->
  nativeArgs = []
  for arg in args
    nativeArgs.push @toNative arg

  return nativeArgs

# fully wrap a native function to be used inside the interpreter
# parent: scope of the function to be added to
# name: name of the function in said scope
# fn: the native function
# thisObj: the `this` object the function should be called by
Interpreter::setNativeFn = ( parent, name, fn, thisObj ) ->
  @setProperty parent, name, @wrapNativeFn fn, thisObj

Interpreter::wrapNativeFn = ( fn, thisObj ) ->
  thisIP = @
  @createNativeFunction ( args... ) ->
    thisObj ?= @ if !@.NaN # don't convert window
    thisIP.fromNative fn.apply thisObj, thisIP.convertArgsToNative args...

# fully wrap an asynchronous native function, see wrapNativeFn
Interpreter::wrapNativeAsyncFn = ( parent, name, fn, thisObj ) ->
  thisIP = @
  @setProperty parent, name, @createAsyncFunction ( args..., callback ) ->
    thisObj ?= @ if !@.NaN # don't convert window
    nativeArgs = thisIP.convertArgsToNative args...
    nativeArgs.unshift ( result ) -> callback thisIP.fromNative(result), true
    fn.apply thisObj, nativeArgs
  return

# wrap a whole class, see wrapNativeFn (doesn't work with async functions)
# scope: the scope for the class to be added to
# name: name of the class in said scope
# $class: the native class instance
# fns: optional, list of names of functions to be wrapped
Interpreter::wrapClass = ( scope, name, $class, fns ) ->
  obj = @createObject @OBJECT
  @setProperty scope, name, obj

  if !fns?
    fns = []
    for key, fn of $class
      fns.push key if typeof fn == "function"

  for fn in fns
    @wrapNativeFn obj, fn, $class[ fn ], $class

# transfer object from the sandbox to the outside by name
Interpreter::retrieveObject = ( scope, name ) ->
  return @toNative @getProperty scope, name

# transfer object from the outside into the sandbox by name
Interpreter::transferObject = ( scope, name, obj ) ->
  @setProperty scope, name, @fromNative obj, scope, name
  return

# call a sandbox function at the current state of the interpreter
# fn: sandbox type function
# args: any native arguments to the function
# done: callback to be run when the function call is done
Interpreter::callScriptMethod = ( delegate, fn, args..., done ) ->
  scope = @createScope fn.node.body, fn.parentScope
  if delegate?
    @setProperty scope, 'delegate', new DefaultDelegate @, delegate

  for p, i in fn.node.params
    @setProperty scope, @createPrimitive(p.name), @fromNative(args[ i ])

  argsList = @createObject @ARRAY
  for arg, i in args
    @setProperty argsList, @createPrimitive(i), @fromNative(arg)

  @setProperty scope, "arguments", argsList

  # remove returns from callbacks
  [..., last] = fn.node.body.body
  if last?.type == "ReturnStatement"
    last.type = "ExpressionStatement"
    last.expression = last.argument
    delete last.argument

  funcState =
    node : fn.node.body
    scope : scope
    thisExpression : @stateStack[ 0 ].funcThis_

  ip = new Interpreter ""
  ip.stateStack.unshift funcState
  ip.run done

module.exports = Interpreter
