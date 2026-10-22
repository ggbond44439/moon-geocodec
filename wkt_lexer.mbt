///|
pub(all) enum WktTokenKind {
  Word
  Number
  LParen
  RParen
  Comma
  Semicolon
  Equals
  End
} derive(Eq, @debug.Debug)

///|
pub fn WktTokenKind::name(self : WktTokenKind) -> String {
  match self {
    Word => "word"
    Number => "number"
    LParen => "lparen"
    RParen => "rparen"
    Comma => "comma"
    Semicolon => "semicolon"
    Equals => "equals"
    End => "end"
  }
}

///|
pub(all) struct WktToken {
  kind : WktTokenKind
  text : String
  offset : Int32
} derive(Eq, @debug.Debug)

///|
pub fn WktToken::kind(self : WktToken) -> WktTokenKind {
  self.kind
}

///|
pub fn WktToken::text(self : WktToken) -> String {
  self.text
}

///|
pub fn WktToken::offset(self : WktToken) -> Int32 {
  self.offset
}

///|
fn is_wkt_space(code : UInt16) -> Bool {
  code == 32 || code == 9 || code == 10 || code == 13
}

///|
fn is_ascii_digit(code : UInt16) -> Bool {
  code >= 48 && code <= 57
}

///|
fn is_ascii_alpha(code : UInt16) -> Bool {
  (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
}

///|
fn is_word_start(code : UInt16) -> Bool {
  is_ascii_alpha(code) || code == 95
}

///|
fn is_word_continue(code : UInt16) -> Bool {
  is_word_start(code) || is_ascii_digit(code)
}

///|
fn token_text(source : StringView, start : Int32, end : Int32) -> String {
  source.view(start_offset=start, end_offset=end).to_owned()
}

///|
fn scan_word_end(source : StringView, start : Int32) -> Int32 {
  let length = source.length()
  let mut index = start + 1
  while index < length && is_word_continue(source.at(index)) {
    index += 1
  }
  index
}

///|
fn scan_number_end(
  source : StringView,
  start : Int32,
) -> Result[Int32, GeoError] {
  let length = source.length()
  let mut index = start
  if index < length && (source.at(index) == 43 || source.at(index) == 45) {
    index += 1
  }
  let integer_start = index
  while index < length && is_ascii_digit(source.at(index)) {
    index += 1
  }
  let mut has_digits = index > integer_start
  if index < length && source.at(index) == 46 {
    index += 1
    let fraction_start = index
    while index < length && is_ascii_digit(source.at(index)) {
      index += 1
    }
    if index > fraction_start {
      has_digits = true
    }
  }
  if !has_digits {
    return Err(InvalidWkt("invalid number", start))
  }
  if index < length && (source.at(index) == 69 || source.at(index) == 101) {
    index += 1
    if index < length && (source.at(index) == 43 || source.at(index) == 45) {
      index += 1
    }
    let exponent_start = index
    while index < length && is_ascii_digit(source.at(index)) {
      index += 1
    }
    if index == exponent_start {
      return Err(InvalidWkt("invalid exponent", start))
    }
  }
  if index < length &&
    (is_word_continue(source.at(index)) || source.at(index) == 46) {
    return Err(InvalidWkt("invalid number suffix", start))
  }
  Ok(index)
}

///|
pub fn tokenize_wkt(
  source : StringView,
  limits : GeoLimits,
) -> Result[Array[WktToken], GeoError] {
  match limits.check_text(source.length()) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let tokens : Array[WktToken] = []
  let length = source.length()
  let mut index = 0
  while index < length {
    let code = source.at(index)
    if is_wkt_space(code) {
      index += 1
    } else if is_word_start(code) {
      let end = scan_word_end(source, index)
      tokens.push({
        kind: Word,
        text: token_text(source, index, end),
        offset: index,
      })
      index = end
    } else if is_ascii_digit(code) || code == 43 || code == 45 || code == 46 {
      let end = match scan_number_end(source, index) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      tokens.push({
        kind: Number,
        text: token_text(source, index, end),
        offset: index,
      })
      index = end
    } else {
      let kind = match code {
        40 => LParen
        41 => RParen
        44 => Comma
        59 => Semicolon
        61 => Equals
        _ => return Err(InvalidWkt("unexpected character", index))
      }
      tokens.push({
        kind,
        text: token_text(source, index, index + 1),
        offset: index,
      })
      index += 1
    }
  }
  match limits.check_tokens(tokens.length() + 1) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  tokens.push({ kind: End, text: "", offset: length, })
  Ok(tokens)
}

///|
pub extend WktTokenKind with Eq::{not_equal, equal}

///|
pub extend WktTokenKind with @debug.Debug::{to_repr}

///|
pub extend WktToken with Eq::{not_equal, equal}

///|
pub extend WktToken with @debug.Debug::{to_repr}
