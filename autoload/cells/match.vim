
fun! cells#match#MatchScoreFunctionDefault(d, s)
    if a:s =~ a:d.regex_camel_case_like
      return 2
    elseif a:s =~ a:d.regex_prefix
      return 1.5
    elseif a:s =~ a:d.regex_ignore_case
      return 0.5
    else
      return 0
    endif
endf

fun! cells#match#MatchScoreFunction(word)
  let d = {}
  let quoted = substitute(a:word, '\([(]\)','[\1]' ,'g')
  let d.regex_camel_case_like = '^'.cells#util#CamelCaseLikeMatching(a:word)
  let d.regex_prefix = '^'. quoted
  let d.regex_ignore_case = '^\v'. quoted
  return function('cells#match#MatchScoreFunctionDefault', [d])
endf
