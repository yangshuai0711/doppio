
# pull in external modules
_ ?= require '../third_party/underscore-min.js'

# things assigned to root will be available outside this module
root = exports ? this.util = {}

root.sum = (list) -> _.reduce(list, ((a,b) -> a+b), 0)

root.padleft = (str,len,fillchar) ->
  throw "fillchar can only be length 1" unless fillchar.length == 1
  # I hate this.
  until str.length >= len
    str = fillchar + str
  return str

root.cmp = (a,b) ->
  return 0  if a == b
  return -1 if a < b
  return 1 if a > b
  return null # this will occur if either a or b is NaN

# implments x<<n without the braindead javascript << operator
# (see http://stackoverflow.com/questions/337355/javascript-bitwise-shift-of-long-long-number)
root.lshift = (x,n) -> x*Math.pow(2,n)

root.bitwise_not = (x,nbits) ->
  s = root.padleft(x.toString(2),nbits,'0')
  # may the computer gods have mercy on our souls...
  not_s = s.replace(/1/g,'x').replace(/0/g,'1').replace(/x/g,'0')
  return parseInt(not_s,2)

root.read_uint = (bytes) -> 
  n = bytes.length-1
  # sum up the byte values shifted left to the right alignment.
  root.sum(root.lshift(bytes[i],8*(n-i)) for i in [0..n])

root.bytestr_to_array = (bytecode_string) ->
  (bytecode_string.charCodeAt(i) & 0xFF for i in [0...bytecode_string.length])

root.unarray = (typestr) -> # strips one level of array from type sig
  if typestr[1] is 'L' and typestr[typestr.length-1] is ';'
    typestr.slice(2,typestr.length-1)
  else
    typestr.slice(1)

root.parse_flags = (flag_byte) ->
  {
    public:       flag_byte & 0x1
    private:      flag_byte & 0x2
    protected:    flag_byte & 0x4
    static:       flag_byte & 0x8
    final:        flag_byte & 0x10
    synchronized: flag_byte & 0x20
    super:        flag_byte & 0x20
    volatile:     flag_byte & 0x40
    transient:    flag_byte & 0x80
    native:       flag_byte & 0x100
    interface:    flag_byte & 0x200
    abstract:     flag_byte & 0x400
    strict:       flag_byte & 0x800
  }

class root.BytesArray
  constructor: (@raw_array) ->
    @index = 0

  has_bytes: -> @index < @raw_array.length

  get_uint: (bytes_count) ->
    rv = root.read_uint @raw_array.slice(@index, @index+bytes_count)
    @index += bytes_count
    return rv

  get_int: (bytes_count) ->
    uint = @get_uint(bytes_count)
    if uint > Math.pow 2, 8 * bytes_count - 1
      uint - Math.pow 2, 8 * bytes_count
    else
      uint

root.is_string = (obj) -> typeof obj == 'string' or obj instanceof String

# Walks up the prototype chain of :object looking for an entry in the :handlers
# dict that match its constructor's name. If it finds one, it calls that handler
# with :object bound to `this` and :args as the arguments.
root.lookup_handler = (handlers, object, args...) ->
  obj = object
  while obj?
    handler = handlers[obj.constructor.name]
    return handler.apply object, args if handler
    obj = Object.getPrototypeOf obj

class root.ReturnException
  constructor: (@values...) ->

class root.JavaException
  # yeah, naming gets a little confusing here
  constructor: (rs, @exception_ref) ->
    @exception = rs.get_obj @exception_ref
    # CS' inheritance mechanism doesn't allow us to inherit from
    # Error.prototype without instantiating it. Hence this hack is necessary to
    # allow us to get the stacktrace at the correct position.
    @stack = (new Error).stack
