module ArkoudaRegexCompat {
  use Regex;

  record regexCompat {
    const pattern: string;
    const cp = compile(pattern);
    
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