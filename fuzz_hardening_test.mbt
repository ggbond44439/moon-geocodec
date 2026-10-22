///|
priv struct FuzzRng {
  mut state : UInt64
}

///|
fn FuzzRng::new(seed : UInt64) -> FuzzRng {
  { state: seed, }
}

///|
fn FuzzRng::next(self : FuzzRng) -> UInt64 {
  self.state = self.state * 6364136223846793005UL + 1442695040888963407UL
  self.state
}

///|
fn FuzzRng::byte(self : FuzzRng) -> Byte {
  (self.next() >> 56).to_byte()
}

///|
test "random WKB and EWKB inputs fail safely" {
  let rng = FuzzRng::new(0x9e3779b97f4a7c15UL)
  let limits = @moon_geocodec.GeoLimits::default()
  for _ in 0..<256 {
    let length = (rng.next() % 64UL).to_int()
    let raw : Array[Byte] = []
    for _ in 0..<length {
      raw.push(rng.byte())
    }
    let bytes = Bytes::from_array(raw)
    ignore(@moon_geocodec.parse_wkb(bytes.exact_view(), limits))
    ignore(@moon_geocodec.parse_ewkb(bytes.exact_view(), limits))
  }
}

///|
test "truncated text formats fail safely" {
  let limits = @moon_geocodec.GeoLimits::default()
  let wkt_samples = [
    "POINT Z (1 2 3)", "POLYGON ((0 0, 1 0, 1 1, 0 0))", "GEOMETRYCOLLECTION (POINT (1 2), LINESTRING (0 0, 1 1))",
  ]
  for source in wkt_samples {
    let end_limit = source.length() + 1
    for end in 0..<end_limit {
      ignore(@moon_geocodec.parse_wkt(source.view(end_offset=end), limits))
      ignore(@moon_geocodec.parse_wkt2(source.view(end_offset=end), limits))
    }
  }
  let json_samples = [
    "{\"type\":\"Point\",\"coordinates\":[1,2]}", "{\"type\":\"GeometryCollection\",\"geometries\":[{\"type\":\"Point\",\"coordinates\":[1,2]}]}",
  ]
  for source in json_samples {
    let end_limit = source.length() + 1
    for end in 0..<end_limit {
      ignore(@moon_geocodec.parse_geojson(source.view(end_offset=end), limits))
    }
  }
}

///|
test "WKB input byte limits are enforced" {
  let valid = "0101000000000000000000f03f0000000000000040"
  let raw : Array[Byte] = []
  let mut high = -1
  for character in valid.iter() {
    let digit = if character.to_int() >= 48 && character.to_int() <= 57 {
      character.to_int() - 48
    } else if character.to_int() >= 97 && character.to_int() <= 102 {
      character.to_int() - 97 + 10
    } else {
      fail("invalid test hex")
    }
    if high < 0 {
      high = digit
    } else {
      raw.push((high * 16 + digit).to_byte())
      high = -1
    }
  }
  let limits = match @moon_geocodec.GeoLimits::new(4, 8, 8, 8) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(
    @moon_geocodec.parse_wkb(Bytes::from_array(raw).exact_view(), limits),
    Err(@moon_geocodec.LimitExceeded("text bytes", 4, 21)),
  )
}
