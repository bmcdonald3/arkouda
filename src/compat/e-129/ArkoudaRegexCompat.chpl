module ArkoudaRegexCompat {
  use Regex;

  record regexCompat {
    type eltType;
    const pattern: eltType;
    const cp = compile(pattern);

    proc init(pat: ?t) {
      eltType = t;
      pattern = pat;
    }
    
    proc match(name) {
      return cp.match(name);
    }
    proc search(text):regexMatch {
      return cp.search(text);
    }
    iter matches(text, param captures=0) {
      for match in cp.matches(text, captures) {
        yield match;
      }
    }
  }
}