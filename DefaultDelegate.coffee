_ = require 'lodash'
rek = require 'rekuire'
log = rek('logger')(require('path').basename(__filename).split('.')[ 0 ])
{EventEmitter} = require 'events'

class DefaultDelegate extends EventEmitter
  constructor : ( @interpreter, @handler ) ->

  hasProperty : ( name ) =>
    if @handler?.hasProperty?
      return true if @handler.hasProperty(name)
    else
      log.v "hasProperty: #{name}"
      true

  hasMethod : ( name ) =>
    if @handler?.hasMethod?
      @handler.hasMethod(name)
    else
      log.v "hasProperty: #{name}"
      true

  getProperty : ( name ) =>
    if @handler?.getProperty?
      val = @handler.getProperty(name)
    else
      log.v "getProperty: #{name}"
      val = name
    @interpreter.fromNative val

  getMethod : ( name ) =>
    log.v "getMethod: #{name}"
    if typeof @handler?[ name ] is 'function'
      f = ( args... ) => 
        @handler[ name ] args...
        undefined
    else if @handler?.getMethod?
      f = ( args... ) => 
        @handler.getMethod(name) args...
        undefined
    else if !@handler
      f = ( args... ) => @invokeMethod name, args
    return @interpreter.wrapNativeFn f if f

  setProperty : ( name, value ) =>
    if @handler?.setProperty?
      @handler?.setProperty? name, @interpreter.toNative value
    else
      log.v "setProperty: #{name}, #{value}"

  invokeMethod : ( name, args ) =>
    log.v "invokeMethod: #{name}, #{args}"
    _.flatten [ name, args ]

module.exports = DefaultDelegate