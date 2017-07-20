" Vim was ahead of its time :-) It spoke JSON before the Web discovered it - haha
" Then it learned to sepeak json in a broken way, turning '' into null using
" json_encode, so we still need this implementation


" If you'r Vim doesn't know about null see old implemenation at vim-addon-json

fun! cells#json#NULL()
  " return function("cells#json#NULL")
  return v:null
endf
fun! cells#json#True()
  " return function("cells#json#True")
  return v:true
endf
fun! cells#json#False()
  " return function("cells#json#False")
  return v:false
endf
fun! cells#json#ToJSONBool(i)
  return  a:i ? cells#json#True() : cells#json#False()
endf

" optional arg: if true then append \n to , of top level dict
fun! cells#json#Encode(thing, ...)
  return cells#json#Encode2(a:thing)
endf
fun! cells#json#Encode2(thing, ...)
  let nl = a:0 > 0 ? (a:1 ? "\n" : "") : ""
  if type(a:thing) == type("")
    return '"'.escape(a:thing,'"\').'"'
  elseif type(a:thing) == type({}) && !has_key(a:thing, 'json_special_value')
    let pairs = []
    for [Key, Value] in items(a:thing)
      call add(pairs, cells#json#Encode2(Key).':'.cells#json#Encode2(Value))
      unlet Key | unlet Value
    endfor
    return "{".nl.join(pairs, ",".nl)."}"
  elseif type(a:thing) == type(0)
    return a:thing
  elseif type(a:thing) == type([])
    return '['.join(map(copy(a:thing), "cells#json#Encode2(v:val)"),",").']'
    return 
  elseif a:thing == v:null
    return "null"
  elseif a:thing == v:true
    return "true"
  elseif a:thing == v:false
    return "false"
  else
    throw "unexpected new thing: ".string(a:thing)
  endif
endf

" if you want cells#json#Encode(cells#json#Decode(str)) == str
" then you have to assign true to cells#json#True() etc.
" I don't have a use case so I use Vim encoding
fun! cells#json#Decode(s)
  let true = 1
  let false = 0
  let null = 0
  return eval(a:s)
endf

fun! cells#json#DecodePreserve(s)
  let true = cells#json#True()
  let false = cells#json#False()
  let null = cells#json#NULL()
  return eval(a:s)
endf

" usage example: echo cells#json#Encode({'method': 'connection-info', 'id': 0, 'params': [3]})
