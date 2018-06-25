
fun! cells#match#MatchScoreFunctionDefault(d, s)
  try
    if a:s =~ a:d.regex_camel_case_like
      return 1.0
    elseif a:s =~ a:d.regex_prefix
      return 0.01
    elseif a:s =~ a:d.regex_ignore_case
      return 0.05
    else
      return 0
    endif
  catch /.*/
    debug echom v:exception
    return 0
  endtry
endf

fun! cells#match#MatchScoreFunction(word)
  let d = {}
  let quoted = substitute(a:word, '\([?@%=#)({*+]\)','[\1]' ,'g')
  let d.regex_camel_case_like = '^'.cells#util#CamelCaseLikeMatching(a:word)
  let d.regex_prefix = '^'. quoted
  let d.regex_ignore_case = '^\v'. quoted
  return function('cells#match#MatchScoreFunctionDefault', [d])
endf
