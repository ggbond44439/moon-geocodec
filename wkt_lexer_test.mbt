///|
test "WKT lexer emits keywords numbers punctuation and offsets" {
  let limits = @moon_geocodec.GeoLimits::default()
  let tokens = match
    @moon_geocodec.tokenize_wkt("POINT Z (1 -2.5, .5e2)", limits) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(tokens.length(), 9)
  assert_eq(tokens[0].kind(), @moon_geocodec.WktTokenKind::Word)
  assert_eq(tokens[0].text(), "POINT")
  assert_eq(tokens[0].offset(), 0)
  assert_eq(tokens[1].text(), "Z")
  assert_eq(tokens[2].kind(), @moon_geocodec.WktTokenKind::LParen)
  assert_eq(tokens[3].text(), "1")
  assert_eq(tokens[4].text(), "-2.5")
  assert_eq(tokens[5].kind(), @moon_geocodec.WktTokenKind::Comma)
  assert_eq(tokens[6].text(), ".5e2")
  assert_eq(tokens[7].kind(), @moon_geocodec.WktTokenKind::RParen)
  assert_eq(tokens[8].kind(), @moon_geocodec.WktTokenKind::End)
  assert_eq(tokens[8].offset(), 22)
}

///|
test "WKT lexer supports WKT2 separators and signed exponents" {
  let limits = @moon_geocodec.GeoLimits::default()
  let tokens = match
    @moon_geocodec.tokenize_wkt("SRID=4326;POINT(+1 -1e-2)", limits) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(tokens[1].kind(), @moon_geocodec.WktTokenKind::Equals)
  assert_eq(tokens[3].kind(), @moon_geocodec.WktTokenKind::Semicolon)
  assert_eq(tokens[6].text(), "+1")
  assert_eq(tokens[7].text(), "-1e-2")
}

///|
test "WKT lexer rejects malformed input with useful offsets" {
  let limits = @moon_geocodec.GeoLimits::default()
  assert_eq(
    @moon_geocodec.tokenize_wkt("POINT@", limits),
    Err(@moon_geocodec.InvalidWkt("unexpected character", 5)),
  )
  assert_eq(
    @moon_geocodec.tokenize_wkt("POINT(1e)", limits),
    Err(@moon_geocodec.InvalidWkt("invalid exponent", 6)),
  )
  assert_eq(
    @moon_geocodec.tokenize_wkt("POINT(12abc)", limits),
    Err(@moon_geocodec.InvalidWkt("invalid number suffix", 6)),
  )
  assert_eq(
    @moon_geocodec.tokenize_wkt("POINT(. )", limits),
    Err(@moon_geocodec.InvalidWkt("invalid number", 6)),
  )
}

///|
test "WKT lexer enforces text and token limits" {
  let small_text = match @moon_geocodec.GeoLimits::new(3, 8, 8, 8) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(
    @moon_geocodec.tokenize_wkt("POINT", small_text),
    Err(@moon_geocodec.LimitExceeded("text bytes", 3, 5)),
  )
  let base = @moon_geocodec.GeoLimits::default()
  let small_tokens = match base.with_token_limit(3) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(
    @moon_geocodec.tokenize_wkt("POINT(1 2)", small_tokens),
    Err(@moon_geocodec.LimitExceeded("token count", 3, 6)),
  )
  assert_eq(
    base.with_token_limit(0),
    Err(@moon_geocodec.InvalidLimit("max_tokens", 0)),
  )
}
